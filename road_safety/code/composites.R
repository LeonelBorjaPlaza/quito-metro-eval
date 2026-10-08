# Composite donors (candidate 2, Leonel 2026-09-27). Sourced by code/power_units.R after the volume
# screen and before any later start is applied, so it sees January 2021 to November 2023.
# Merging rule, written before any run (plan section 4; docs/correspondence/2026-09-27_road_safety_design_decisions.md):
# - Candidates: parishes entirely beyond 2 km of the line, not crossed by the Trolebus or Ecovia
#   (Guamani counted as crossed), that fail the volume screen. Parishes that pass on their own stay
#   single donors and are never merged.
# - Neighbours: GeoQuito polygons that share a boundary line, not just a point (st_relate "F***1****").
# - Seed: the unassigned failing parish with the most pre-period crashes (ties by DPA code). Growth:
#   add the unassigned failing neighbour of the composite with the most pre-period crashes (ties by
#   DPA code) until the composite passes the screen (at least 3 crashes a month, at most 20 percent of
#   months without one, January 2021 to November 2023); then start a new seed. A group that cannot
#   reach the screen is dropped and listed.
# - It uses only the screen's own quantities (all-crash volume and months with a crash), never fit,
#   fake effects or injury counts. A composite is flagged if any member is crossed by the Central Norte.
stopifnot(file.exists(PARISH_ZIP), substr(system2("sha256sum", shQuote(PARISH_ZIP), stdout = TRUE), 1, 64) == PARISH_SHA256)
comp_poly <- st_transform(st_read(paste0("/vsizip/", normalizePath(PARISH_ZIP)), quiet = TRUE), CRS_UTM)
comp_poly$parish_code <- as.integer(comp_poly$dpa_parroq)
comp_stats <- function(codes) {  # all-crash count and months with a crash (zero rows give 0 and 0)
  i <- which(pre$parish_code %in% codes); list(n = length(i), m = uniqueN(pre$t_month[i]))
}
comp_passes <- function(s) s$n / length(months) >= MIN_DONOR_MEAN & 1 - s$m / length(months) <= MAX_DONOR_ZERO_SHARE
comp_cand <- ptab[wholly_beyond_2km == TRUE & brt_core_crosses_part_beyond_2km == FALSE,
                  .(parish_code, parish, urban, central_norte = brt_any_crosses_part_beyond_2km)]
comp_cand[, crashes := vapply(parish_code, function(p) comp_stats(p)$n, 0L)]
comp_cand[, passes := vapply(parish_code, function(p) comp_passes(comp_stats(p)), TRUE)]
failing <- comp_cand[passes == FALSE][order(parish_code)]
stopifnot(setequal(comp_cand[passes == TRUE, parish], unique(donor_sets_b$B_parishes_beyond_2km$unit)),
          nrow(failing) == 30L)
pf <- comp_poly[match(failing$parish_code, comp_poly$parish_code), ]
stopifnot(!anyNA(pf$parish_code))
comp_adj <- st_relate(pf, pf, pattern = "F***1****")
# Overlapping polygons would fail the pattern and silently lose a neighbour: stop if any pair of
# candidate parishes shares interior area (code review pass 5).
comp_int <- st_intersects(pf, pf)
comp_overlap <- sum(vapply(seq_len(nrow(pf)), function(i) {
  j <- setdiff(comp_int[[i]], c(i, comp_adj[[i]]))
  if (!length(j)) return(0) else sum(as.numeric(st_area(suppressWarnings(st_intersection(st_geometry(pf)[i], st_geometry(pf)[j]))))) }, 0))
stopifnot(comp_overlap < 1,  # square metres
          all(lengths(st_relate(pf, pf, pattern = "2********")) == 1L))  # no interior overlap of any size (pass 5b)
by_volume <- function(codes) codes[order(-failing$crashes[match(codes, failing$parish_code)], codes)]
unassigned <- failing$parish_code
comp_groups <- list(); comp_dropped <- list()
while (length(unassigned)) {
  members <- by_volume(unassigned)[1]
  unassigned <- setdiff(unassigned, members)
  repeat {
    if (comp_passes(comp_stats(members))) break
    nb <- failing$parish_code[unique(unlist(comp_adj[match(members, failing$parish_code)]))]
    nb <- intersect(nb, unassigned)
    if (!length(nb)) break
    add <- by_volume(nb)[1]
    members <- c(members, add); unassigned <- setdiff(unassigned, add)
  }
  if (comp_passes(comp_stats(members))) comp_groups[[length(comp_groups) + 1L]] <- members
  else comp_dropped[[length(comp_dropped) + 1L]] <- members
}
comp_name <- function(codes) paste0("COMPOSITE: ", paste(failing$parish[match(codes, failing$parish_code)], collapse = " + "))
composites <- rbindlist(lapply(comp_groups, function(g) {
  s <- comp_stats(g)
  data.table(composite = comp_name(g), members = length(g),
             urban_members = sum(failing$urban[match(g, failing$parish_code)]),
             central_norte = any(failing$central_norte[match(g, failing$parish_code)]),
             crashes_per_month = round(s$n / length(months), 2), zero_month_share = round(1 - s$m / length(months), 3))
}))
composite_dropped <- rbindlist(lapply(comp_dropped, function(g) data.table(
  parishes = paste(failing$parish[match(g, failing$parish_code)], collapse = " + "), members = length(g))))
# The rule, checked: members contiguous (each added member touches the group by construction),
# entirely beyond 2 km, not Trolebus or Ecovia crossed, every composite passes, no passing parish merged,
# every failing parish used once.
comp_codes <- unlist(comp_groups)
connected <- function(g) {  # every member reachable from the first through shared boundaries within the group
  seen <- g[1]; repeat { nb <- intersect(failing$parish_code[unlist(comp_adj[match(seen, failing$parish_code)])], g)
    new <- setdiff(nb, seen); if (!length(new)) break; seen <- c(seen, new) }
  setequal(seen, g)
}
stopifnot(all(vapply(comp_groups, connected, TRUE)))
stopifnot(!anyDuplicated(c(comp_codes, unlist(comp_dropped))),
          setequal(c(comp_codes, unlist(comp_dropped)), failing$parish_code),
          all(comp_codes %in% ptab[wholly_beyond_2km == TRUE & brt_core_crosses_part_beyond_2km == FALSE, parish_code]),
          !any(comp_codes %in% comp_cand[passes == TRUE, parish_code]),
          all(vapply(comp_groups, function(g) comp_passes(comp_stats(g)), TRUE)))
comp_rows <- rbindlist(lapply(comp_groups, function(g) pre[parish_code %in% g, tag(.SD, comp_name(g))]))
comp_cn <- composites[central_norte == TRUE, composite]
donor_sets_c <- lapply(list(
  C_pool_b_plus_composites = rbind(donor_sets_b$B_parishes_beyond_2km, comp_rows),
  C_no_central_norte = rbind(donor_sets_b$B_no_central_norte, comp_rows[!unit %in% comp_cn])), screen)
stopifnot(uniqueN(donor_sets_c$C_pool_b_plus_composites$unit) == uniqueN(donor_sets_b$B_parishes_beyond_2km$unit) + nrow(composites))
