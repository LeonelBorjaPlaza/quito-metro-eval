# Write the candidate-comparison tables and maps to the repository evidence folder (aggregates only).
suppressPackageStartupMessages({ library(data.table); library(sf) })
S <- "/tmp/claude-1000/-home-leonelb-projects-quito-metro-eval/b47a6f2b-9093-4316-bcf4-7d83fcf5dc21/scratchpad/polygons"
D <- "../reports/congestion/2026-09-29_historic_center_candidates"
dir.create(D, showWarnings = FALSE, recursive = TRUE)
cc <- readRDS(file.path(S, "compare_candidates.rds"))
fwrite(as.data.table(st_drop_geometry(cc$cand)), file.path(D, "areas.csv"))
fwrite(cc$ov, file.path(D, "overlaps.csv"))
fwrite(cc$lm, file.path(D, "landmarks.csv"))
fwrite(cc$hex, file.path(D, "hexagons_touched.csv"))
ov <- readRDS(file.path(S, "overlay_final.rds"))
fwrite(cbind(ov$share, unesco_map_core_ha = round(ov$core_ha, 1), unesco_map_core_or_buffer_ha = round(ov$any_ha, 1),
             underlay_shift_east_m = round(-ov$shift[1]), underlay_shift_north_m = round(-ov$shift[2])),
       file.path(D, "unesco_map_shares.csv"))
fwrite(readRDS(file.path(S, "core_corners.rds")), file.path(D, "core_corners_vs_osm_trace.csv"))
fwrite(readRDS(file.path(S, "osm_class_calibration.rds")), file.path(D, "osm_class_calibration_2022.csv"))
fwrite(readRDS(file.path(S, "candidate_weights.rds"))$res, file.path(D, "road_length_weights_summary.csv"))
file.copy(file.path(S, "candidates_overlay_unesco.png"), file.path(D, "map_candidates_over_unesco.png"), overwrite = TRUE)
file.copy(file.path(S, "candidates_overlay.png"), file.path(D, "map_candidates_grid.png"), overwrite = TRUE)
dir.create(file.path(D, "scratch_scripts"), showWarnings = FALSE)
for (f in c("compare_candidates.R", "georef_unesco.R", "check_core_corners.R", "overlay_final.R", "calibrate_roads.R",
            "candidate_weights.R", "export_evidence.R", "osm_query.txt", "osm_geom_query.txt", "osm_landmarks.txt",
            "osm_landmarks2.txt", "osm_streets.txt", "osm_roads_2022.txt"))
  file.copy(file.path(S, f), file.path(D, "scratch_scripts", f), overwrite = TRUE)
print(list.files(D, recursive = TRUE))
