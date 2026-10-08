# Model inventory (Leonel, 2026-10-04): descriptive tables for reports/road_safety/2026-10-04_model_inventory.md.
# Run from road_safety/ after 11_p1_estimates.R: Rscript code/12_model_inventory.R
# It loads the specifications of 11_p1_estimates.R by evaluating that script's top-level expressions up to
# the estimation loop (nothing in 11 is re-estimated or rewritten), so the data are the same: pre-period rows
# (load_pre) and December 2023 to August 2024 (load_p1); nothing later. P1 values appear only in the monthly
# gaps, which restate what the P1 estimates already used. No estimate of the P1 report changes.
# Writes output/p1/inventory/ (aggregates only; no counts are published, only means, shares, index values,
# weights and coefficients; small-count rule of amendment section 4.6, condition 7):
#   outcome_moments.csv  pre-period monthly mean, SD and share of zero months, treated area and pooled comparator
#   sc_weights.csv       E3 synthetic-control weights: the ten largest, by parish, and a summary
#   pre_fit.csv          pre-period fit of the gap for the models described
#   fake_openings.csv    inside placements (size check) and forward openings (drift rule), with dates and effects
#   shift_stats_A1.csv   A1's 30 circular shifts: the statistic at each shift (the conformal reference distribution)
#   monthly_gap.csv      monthly gap (index points) for A1, E2 and E3, January 2022 to August 2024
#   monthly_gap.png      the same, with the opening marked and P1 labelled
#   event_study.csv      pre-period Poisson event study, quarterly leads (pre-trends only); model-based intervals
#                        with Poisson standard errors (dispersion fixed at 1; the quasi-Poisson scale is reported)
#   comparator_map.png   zones and parishes (geometry only)
stopifnot(system2("git", c("diff", "--quiet", "HEAD", "--", "code/11_p1_estimates.R")) == 0L)  # 11 as committed
ex <- parse("code/11_p1_estimates.R", keep.source = TRUE)
txt <- vapply(attr(ex, "srcref"), function(s) paste(as.character(s), collapse = "\n"), "")
stop_at <- which(startsWith(txt, "res <- rbindlist("))[1]
stopifnot(!is.na(stop_at))
for (i in seq_len(stop_at - 1L)) eval(ex[[i]], envir = globalenv())
stopifnot(exists("specs"), max(d$fecha) <= P1_END)
inv <- "output/p1/inventory"
dir.create(inv, recursive = TRUE, showWarnings = FALSE)
MODELS <- c("A1", "E2", "E3", "J2", "E5", "C1", "C11", "A2", "B4", "E6", "F2")
mlab <- function(m) format(m, "%Y-%m")

# ---- 1e. Outcome moments, pre-period ----------------------------------------------------------------------
mom <- rbindlist(lapply(c("injury", "all"), function(oc) {
  S <- make_spec("treated", "distant", oc)
  G <- make_spec("treated", "distant", oc, start = "2021-01-01")
  rbindlist(list(
    data.table(window = "A1 panel: January 2022 to November 2023, June 2022 and November 2023 left out (21 months)",
               outcome = oc, series = c("treated area (1 km of a station)", "distant parishes pooled (39)"),
               mean = c(mean(S$Tc[S$train]), mean(S$C[1, S$train])), sd = c(sd(S$Tc[S$train]), sd(S$C[1, S$train])),
               zero_share = c(mean(S$Tc[S$train] == 0), mean(S$C[1, S$train] == 0))),
    data.table(window = "G3 panel: January 2021 to November 2023, the same two months left out (33 months)",
               outcome = oc, series = c("treated area (1 km of a station)", "distant parishes pooled (39)"),
               mean = c(mean(G$Tc[G$train]), mean(G$C[1, G$train])), sd = c(sd(G$Tc[G$train]), sd(G$C[1, G$train])),
               zero_share = c(mean(G$Tc[G$train] == 0), mean(G$C[1, G$train] == 0)))))
}))
stopifnot(all(mom$mean >= 5))
mom[, `:=`(mean = round(mean, 1), sd = round(sd, 1), zero_share = round(zero_share, 3))]
save_csv(mom, file.path(inv, "outcome_moments.csv"))

# ---- 2b. E3 weights and pre-period fit -----------------------------------------------------------------------
pname <- setNames(ptab$parish, ptab$parish_code)
S <- specs$E3[[2]]
kp <- match(S$per[S$train], ALL_M)  # donors: distant parishes with an injury or fatal crash in the kept pre-period months (make_spec's rule)
donors <- distant[vapply(distant, function(pc) sum(tabulate(outcome_rows(d[parish_code == pc], "injury")$t, length(ALL_M))[kp]) > 0, TRUE)]
stopifnot(length(donors) == nrow(S$C))
Y <- build_Y(S, 0); stopifnot(nrow(Y) - 1L == length(donors))
w <- wts(S, Y, S$train)
w_null <- wts(S, Y, seq_len(ncol(Y)))  # the weights the conformal test refits on all kept months
ord <- order(-w)
save_csv(rbind(
  data.table(rank = as.character(1:10), parish = pname[as.character(donors[ord[1:10]])], weight = round(w[ord[1:10]], 4),
             weight_refit_all_months = round(w_null[ord[1:10]], 4)),
  data.table(rank = c("donors", "donors with weight > 0.001", "equal weight (1 / donors)", "smallest weight"),
             parish = "", weight = c(length(w), sum(w > 0.001), round(1 / length(w), 4), round(min(w), 4)),
             weight_refit_all_months = c(length(w_null), sum(w_null > 0.001), round(1 / length(w_null), 4), round(min(w_null), 4)))),
  file.path(inv, "sc_weights.csv"))

fit_row <- function(k) {
  S <- specs[[k]][[2]]
  if (S$scale == "poisson") return(data.table(model = k, note = "Poisson: see the log-scale gap of F1"))
  Y <- build_Y(S, 0); ww <- wts(S, Y, S$train); g <- adjust(S, gap_of(S, Y, ww))
  comp <- colSums(ww * Y[-nrow(Y), , drop = FALSE]); tr <- S$train
  data.table(model = k, training_months = length(tr),  # the gap's training mean is 0 by construction (every index has training mean 1)
             sd_gap_index_points = round(100 * sd(g[tr]), 2), sd_treated_index_points = round(100 * sd(Y[nrow(Y), tr]), 2),
             cor_treated_comparator = round(cor(Y[nrow(Y), tr], comp[tr]), 3), note = "")
}
save_csv(rbindlist(lapply(MODELS, fit_row), fill = TRUE), file.path(inv, "pre_fit.csv"))

# ---- 2d. Fake openings: inside placements (size check) and forward openings (drift rule) ----------------------
fake_rows <- function(k) {
  S <- specs[[k]][[2]]; tr <- S$train; H <- length(S$post); per <- S$per[tr]
  n <- length(tr) - H + 1L
  inside <- rbindlist(lapply(seq_len(n), function(j) {
    Sk <- S; Sk$Tc <- S$Tc[tr]; Sk$C <- S$C[, tr, drop = FALSE]; Sk$post <- j:(j + H - 1L); Sk$train <- setdiff(seq_along(tr), Sk$post)
    if (!is.null(S$season)) Sk$season <- S$season[tr]
    p <- pval(Sk, 0)
    data.table(model = k, kind = "inside placement (size check)", placement = j, window_first = mlab(per[j]), window_last = mlab(per[j + H - 1L]),
               training = "the other kept pre-period months", fake_effect_x100 = round(100 * estimate(Sk)$tau, 2),
               p_value = round(p, 4), floor = round(1 / length(tr), 4), rejects_5pct = p <= 0.05, rejects_10pct = p <= 0.10)
  }))
  mt <- (if (S$start == "2021-01-01") 18L else 12L) %/% (if (S$freq == "quarter") 3L else 1L)
  ffw <- fake_forward(S)
  fwd <- if (length(tr) >= mt + H) rbindlist(lapply((mt + 1L):(length(tr) - H + 1L), function(j)
    data.table(model = k, kind = "forward opening (drift rule)", placement = j, window_first = mlab(per[j]), window_last = mlab(per[j + H - 1L]),
               training = sprintf("%s to %s (%d kept months)", mlab(per[1]), mlab(per[j - 1L]), j - 1L),
               fake_effect_x100 = round(ffw[j - mt], 2)))) else NULL
  rbindlist(list(inside, fwd), fill = TRUE)
}
fk <- rbindlist(lapply(MODELS, fake_rows), fill = TRUE)
chk <- fk[kind == "inside placement (size check)", .(r05 = sum(rejects_5pct), r10 = sum(rejects_10pct), n = .N), by = model]
est <- fread("output/p1/estimates.csv")[id %in% MODELS, .(model = id, size_placements, size_rejections_05, size_rejections_10, forward_fake_effects, inside_fake_effects_range)]
stopifnot(nrow(merge(chk, est, by = "model")) == length(MODELS))
rng <- fk[kind == "inside placement (size check)", .(lo = min(fake_effect_x100), hi = max(fake_effect_x100)), by = model]
rng <- merge(rng, est, by = "model")[, c("lo_c", "hi_c") := tstrsplit(inside_fake_effects_range, " to ", type.convert = TRUE)]
fw <- merge(fk[kind == "forward opening (drift rule)", .(f = fake_effect_x100[1], nf = .N), by = model], est, by = "model")
stopifnot(rng[, all(abs(lo - lo_c) <= 0.051 & abs(hi - hi_c) <= 0.051)],  # committed values are rounded to 0.1
          fw[, all(nf == 1L & abs(f - as.numeric(forward_fake_effects)) <= 0.051)])
stopifnot(all.equal(merge(chk, est, by = "model")[, .(n, r05, r10)], merge(chk, est, by = "model")[, .(n = size_placements, r05 = size_rejections_05, r10 = size_rejections_10)],
                    check.attributes = FALSE))  # the same placements as the committed size check
save_csv(fk, file.path(inv, "fake_openings.csv"))

# ---- 2d. A1's circular shifts (the reference distribution of the conformal p-value) ---------------------------
S <- specs$A1[[2]]; u <- resid_null(S, 0); Tn <- length(u)
sh <- rbindlist(lapply(0:(Tn - 1L), function(j) {
  pos <- ((S$post - 1L + j) %% Tn) + 1L
  data.table(shift = j, window_months = paste(mlab(S$per[pos])[c(1, length(pos))], collapse = " ... "), stat = abs(mean(u[pos])))
}))
sh[, at_least_as_extreme_as_observed := stat >= stat[1] - 1e-12]  # as pval() in 11, on unrounded values
stopifnot(abs(mean(sh$at_least_as_extreme_as_observed) - fread("output/p1/estimates.csv")[id == "A1", p_value]) < 5e-5)
sh[, statistic_abs_mean_residual_x100 := round(100 * stat, 3)][, stat := NULL]
setcolorder(sh, c("shift", "window_months", "statistic_abs_mean_residual_x100"))
save_csv(sh, file.path(inv, "shift_stats_A1.csv"))

# ---- 3a. Monthly gap, A1, E2, E3, January 2022 to August 2024 (left-out months computed with the same bases and weights)
full_m <- ALL_M[ALL_M >= as.Date("2022-01-01")]
fi <- match(full_m, ALL_M)
gap_full <- function(k) {
  S <- specs[[k]][[2]]
  Tfull <- monthly(outcome_rows(unit_rows("treated"), "injury"))[fi]
  Cfull <- if (S$weights == "pooled") matrix(monthly(outcome_rows(unit_rows("distant"), "injury"))[fi], nrow = 1) else
    t(vapply(donors, function(pc) tabulate(outcome_rows(d[parish_code == pc], "injury")$t, length(ALL_M))[fi], numeric(length(fi))))
  if (S$weights == "pooled") stopifnot(all(Tfull >= 5), all(Cfull >= 5))  # every month shown, left-out months included
  M <- rbind(Cfull, Tfull); kept_pre <- match(S$per[S$train], full_m)
  base <- rowMeans(M[, kept_pre, drop = FALSE]); Yf <- M / base
  Yk <- build_Y(S, 0); ww <- wts(S, Yk, S$train)
  g <- Yf[nrow(Yf), ] - colSums(ww * Yf[-nrow(Yf), , drop = FALSE])
  stopifnot(isTRUE(all.equal(unname(g[match(S$per, full_m)]), unname(gap_of(S, Yk, ww)))))  # same as the estimator on kept months
  100 * g
}
mg <- data.table(month = mlab(full_m),
                 status = fifelse(full_m >= P1_START, "P1 (already seen in the P1 estimates)",
                                  fifelse(full_m %in% as.Date(c("2022-06-01", "2023-11-01")), "pre-period, left out of the panel", "pre-period")),
                 A1 = round(gap_full("A1"), 1), E2 = round(gap_full("E2"), 1), E3 = round(gap_full("E3"), 1))
save_csv(mg, file.path(inv, "monthly_gap.csv"))
pm <- melt(mg, id.vars = c("month", "status"), variable.name = "model", value.name = "gap")
pm[, m := as.Date(paste0(month, "-15"))]
pl <- ggplot(pm, aes(m, gap, colour = model)) +
  annotate("rect", xmin = P1_START, xmax = P1_END, ymin = -Inf, ymax = Inf, alpha = 0.08) +
  geom_hline(yintercept = 0, colour = "grey70", linewidth = 0.3) +
  geom_vline(xintercept = P1_START, linetype = "dashed", colour = "grey30") +
  annotate("text", x = P1_START, y = Inf, label = "Opening, 1 Dec 2023", hjust = 1.05, vjust = 1.5, size = 2.8) +
  geom_line(linewidth = 0.6) + geom_point(aes(shape = status), size = 1.6) +
  scale_colour_manual(values = c(A1 = "#C2410C", E2 = "#2563EB", E3 = "#6B7280"),
                      labels = c(A1 = "A1, pooled comparator", E2 = "E2, equal weights", E3 = "E3, synthetic-control weights")) +
  scale_shape_manual(values = c(16, 4, 17)) +
  labs(x = NULL, y = "Gap: treated index minus comparator index (index points)", colour = NULL, shape = NULL,
       title = "Monthly gap, injury or fatal crashes, treated area (1 km) against the distant parishes",
       subtitle = "Shaded: P1, already seen in the P1 estimates. Triangles: months left out of the panel (shown with the same bases and weights).") +
  theme_minimal(base_size = 9.5) + theme(legend.position = "bottom", legend.box = "vertical")
ggsave(file.path(inv, "monthly_gap.png"), pl, width = 8.5, height = 4.8, dpi = 150)

# ---- 3b. Pre-period event study: Poisson, area and month fixed effects, quarterly leads, no controls ----------
es <- function(drop, label) {
  m <- ALL_M[ALL_M >= as.Date("2022-01-01") & ALL_M < P1_START & !ALL_M %in% as.Date(drop)]
  i <- match(m, ALL_M)
  y_t <- monthly(outcome_rows(unit_rows("treated"), "injury"))[i]; y_c <- monthly(outcome_rows(unit_rows("distant"), "injury"))[i]
  q <- quarter_start(m)  # opening-aligned quarters: December to February, March to May, June to August, September to November
  ref <- as.Date("2023-09-01")
  df <- data.frame(y = c(y_c, y_t), treated = rep(0:1, each = length(m)), month = factor(rep(mlab(m), 2)), q = rep(q, 2))
  for (qq in setdiff(sort(unique(q)), ref)) df[[paste0("lead_", format(as.Date(qq, origin = "1970-01-01"), "%Y_%m"))]] <- as.integer(df$treated == 1 & df$q == qq)
  leads <- grep("^lead_", names(df), value = TRUE)
  f <- glm(reformulate(c("treated", "month", leads), "y"), family = poisson(), data = df)  # Poisson: dispersion fixed at 1
  ct <- summary(f)$coefficients[leads, , drop = FALSE]
  disp <- sum(residuals(f, type = "pearson")^2) / f$df.residual  # the quasi-Poisson scale, reported, not used
  qs <- as.Date(paste0(sub("lead_", "", leads), "_01"), "%Y_%m_%d")
  data.table(sample = label, quarter_start = mlab(qs),
             months_in_quarter = vapply(qs, function(qq) paste(mlab(m[q == qq]), collapse = " "), ""),
             coef_log_points = round(ct[, 1], 3), ci95_low = round(ct[, 1] - 1.96 * ct[, 2], 3), ci95_high = round(ct[, 1] + 1.96 * ct[, 2], 3),
             pct = round(100 * (exp(ct[, 1]) - 1), 1), interval = "model-based (Wald), Poisson standard errors",
             quasi_poisson_dispersion = round(disp, 2), residual_df = f$df.residual,
             reference = sprintf("quarter from 2023-09 (%s)", paste(mlab(m[q == ref]), collapse = " ")))
}
save_csv(rbind(es(c("2022-06-01", "2023-11-01"), "A1 months (21; June 2022 and November 2023 left out)"),
               es(character(), "all 23 months")), file.path(inv, "event_study.csv"))

# ---- 1c. Map of the zones (geometry only, no crash data) -------------------------------------------------------
parishes <- st_transform(st_read(paste0("/vsizip/", normalizePath(PARISH_ZIP)), quiet = TRUE), CRS_UTM)
parishes$parish_code <- as.integer(parishes$dpa_parroq)
stopifnot(!any(ptab$wholly_beyond_2km & ptab$brt_core_crosses_part_beyond_2km))  # the Trolebus/Ecovia rule removes no parish here
pt2 <- ptab[, .(parish_code, role = fcase(parish_code == CALDERON, "distant comparator: Calderon (left out in E6)",
                                          parish_code %in% intersect(distant, cn_codes), "distant comparator: crossed by the Central Norte (left out in E4)",
                                          parish_code %in% distant, "distant comparator, other",
                                          default = "not wholly beyond 2 km of the line: excluded"))]
parishes <- merge(parishes, pt2, by = "parish_code"); stopifnot(nrow(parishes) == 65L)
stations <- st_transform(st_zm(st_read(STATIONS_GPKG, quiet = TRUE)), CRS_UTM)
line <- st_union(st_transform(st_zm(st_read(LINE_GPKG, quiet = TRUE)), CRS_UTM))
mp <- ggplot() + geom_sf(data = parishes, aes(fill = role), colour = "white", linewidth = 0.2) +
  geom_sf(data = st_union(st_buffer(stations, 2000)), fill = NA, colour = "#7C3AED", linewidth = 0.4, linetype = "dashed") +
  geom_sf(data = st_union(st_buffer(stations, 1000)), fill = "#C2410C", alpha = 0.35, colour = "#C2410C", linewidth = 0.3) +
  geom_sf(data = line, colour = "black", linewidth = 0.5) +
  scale_fill_manual(values = c("distant comparator, other" = "#93C5FD", "distant comparator: Calderon (left out in E6)" = "#2563EB",
                               "distant comparator: crossed by the Central Norte (left out in E4)" = "#FCD34D",
                               "not wholly beyond 2 km of the line: excluded" = "#E5E7EB")) +
  labs(fill = NULL, title = "Zones of the road safety design: the 39 distant parishes (blue and yellow) are the comparator",
       subtitle = "Orange: treated area (1 km of a station). Dashed: 2 km of a station (outer edge of the ring). Black: Line 1.") +
  theme_void(base_size = 9) + theme(legend.position = "right")
ggsave(file.path(inv, "comparator_map.png"), mp, width = 8, height = 8, dpi = 150)
cat("done\n")
