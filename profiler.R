### Set profiler function ###
## Profiler.
profiler <- function(dt_pop_1, dt_pop_2, agg_func = "count", agg_id, variables) {
  # load libraries
  library(data.table)
  library(parallel)
  
  # convert to data.table
  setDT(dt_pop_1)
  setDT(dt_pop_2)
  
  # loop through each variable and aggregate stats
  dt_1 <- lapply(variables,
                 function(x1) {
                   # print attribute
                   print(paste0("attribute ", x1))
                     
                   # start time
                   start_time <- proc.time()
                     
                   # population distribution
                   if (agg_func == "count") {
                       dt_2 <- dt_pop_1[is.na(get(x1)) == FALSE, .N, get(x1)]
                   } else if (agg_func == "sum") {
                       dt_2 <- dt_pop_1[is.na(get(x1)) == FALSE, sum(get(agg_id)), get(x1)]
                   } else {
                       print("agg_func must be either 'count' or 'sum'")
                   }
                   colnames(dt_2) <- c("value","pop_1_count")
                   dt_2[, value := as.character(value)]
                   dt_2[, attribute := x1]
                   dt_2[, pop_1_percent := pop_1_count / sum(pop_1_count), by = .(attribute)]
                     
                   # sample distribution
                   if (agg_func == "count") {
                       dt_3 <- dt_pop_2[is.na(get(x1)) == FALSE, .N, get(x1)]
                   } else if (agg_func == "sum") {
                       dt_3 <- dt_pop_2[is.na(get(x1)) == FALSE, sum(get(agg_id)), get(x1)]
                   } else {
                       print("agg_func must be either 'count' or 'sum'")
                   }
                   colnames(dt_3) <- c("value","pop_2_count")
                   dt_3[, value := as.character(value)]
                   dt_3[, attribute := x1]
                   dt_3[, pop_2_percent := pop_2_count / sum(pop_2_count), by = .(attribute)]
                     
                   # end time
                   end_time <- proc.time()
                     
                   # print time results
                   print(paste0(round((end_time - start_time)[3], 0), " seconds"))
                     
                   # combine stats
                   dt_4 <- merge(dt_2, dt_3, by.x = c("attribute","value"), by.y = c("attribute","value"), all = TRUE)
                   dt_4[, c("pop_1_count","pop_1_percent","pop_2_count","pop_2_percent") := lapply(.SD, function(x) ifelse(is.na(x), 0, x)), .SDcols = c("pop_1_count","pop_1_percent","pop_2_count","pop_2_percent")]
                     
                   # Evaluate z-scores per value proportion and information value
                   # Note we add dummy value to replace 0 counts
                   dt_4[, c("pop_1_count","pop_2_count") := lapply(.SD, function(x) ifelse(is.na(x), 0, x)), .SDcols = c("pop_1_count","pop_2_count")]
                   dt_4[, pop_1_count_dummy := ifelse(pop_1_count == 0, 1, pop_1_count)]
                   dt_4[, pop_1_percent_dummy := pop_1_count_dummy / sum(pop_1_count_dummy), by = .(attribute)]
                   dt_4[, pop_2_count_dummy := ifelse(pop_2_count == 0, 1, pop_2_count)]
                   dt_4[, pop_2_percent_dummy := pop_2_count_dummy / sum(pop_2_count_dummy), by = .(attribute)]
                   z_score <- sapply(1:nrow(dt_4),
                                     function(x2) {
                                       z_val <- prop.test(x = c(dt_4[x2, pop_1_count_dummy], dt_4[x2, pop_2_count_dummy]),
                                                          n = c(dt_4[, sum(pop_1_count_dummy)], dt_4[, sum(pop_2_count_dummy)]),
                                                          alternative = "two.sided")
                                       z_val <- sign(z_val$estimate[1] - z_val$estimate[2]) * sqrt(z_val$statistic)
                                       return(z_val)
                                     })
                   dt_4[, index := ifelse(pop_1_percent == 0 | pop_2_percent == 0, Inf, (pop_1_percent / pop_2_percent) - 1)]
                   dt_4[, z_score := z_score]
                   dt_4[, weight_of_evidence := log(x = (pop_1_percent_dummy / pop_2_percent_dummy), base = exp(1))]
                   dt_4[, information_value := (pop_1_percent_dummy - pop_2_percent_dummy) * weight_of_evidence]
                   dt_4[, pop_1_count_dummy := NULL]
                   dt_4[, pop_1_percent_dummy := NULL]
                   dt_4[, pop_2_count_dummy := NULL]
                   dt_4[, pop_2_percent_dummy := NULL]
                     
                   return(dt_4)
                 })
  
  # combine and return results
  dt_1 <- rbindlist(l = dt_1, use.names = TRUE, fill = TRUE)
  return(dt_1)
}
