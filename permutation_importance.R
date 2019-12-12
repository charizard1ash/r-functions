library(data.table)

permutation_importance <- function(dt, y, model, model_name, pred_func="predict(object=model, newdata=dt, type=\"response\"", loss="logloss", class_0_1_prob=TRUE, n_perm=20) {
  # names of predictor variables
  dt_x_var <- names(dt[, .SD, .SDcols=-y])
  
  # distribution of predictions based on randomising each variable
  x_out <- lapply(dt_x_var,
                  function(x1) {
                    if (loss=="logloss") { # log-loss output
                      if (class_0_1_prob==TRUE) { # for binary classification with only (0,1) set values
                        # log-loss for model
                        dt_temp <- dt # dummy temp table to replaced by original
                        x_char <- sapply(dt, is.character) # transform character variables to factor, maintain order in model.matrix pivot
                        x_char <- names(x_char[x_char==TRUE])
                        dt[, c(x_char):=lapply(.SD, as.factor), .SDcols=x_char]
                        dt <- data.table(model.matrix(~., data=dt)[, -1])
                        y_prob <- eval(parse(text=pred_func)) # output of probabilities
                        y_loss_temp <- ifelse(dt[, get(y)]==1, y_prob, 1-y_prob)
                        y_loss <- -sum(log(y_loss_temp))
                        dt <- dt_temp # return original dataset
                        
                        # log-loss based on each randomised permutation for selected variable
                        x_out2 <- lapply(1:n_perm,
                                         function(x2) {
                                           dt_2 <- dt
                                           dt_2[, (x1):=dt_2[sample(x=1:dt_2[, .N], size=dt_2[, .N], replace=FALSE), get(x1)]]
                                           dt_2 <- data.table(model.matrix(~., data=dt_2)[, -1])
                                           y_2_prob <- eval(parse(text=gsub("=dt", "dt_2", pred_func)))
                                           y_2_loss_temp <- ifelse(dt_2[, get(y)]==1, y_2_prob, 1-y_2_prob)
                                           y_2_loss <- -sum(log_y_2_loss_temp)
                                           dt_2 <- data.table(model_name=model_name, iteration=x2, loss_func_diff=y_2_loss-y_loss)
                                           return(dt_2)
                                         })
                        x_out2 <- rbindlist(l=x_out2, use.names=TRUE, fill=TRUE)
                        return(x_out2)
                      } else if (class_0_1_prob==FALSE) { # for multi-class classification
                        # log-loss for model
                        dt_temp <- dt # dummy temp table to replaced by original
                        x_char <- sapply(dt, is.character) # transform character variables to factor, maintain order in model.matrix pivot
                        x_char <- names(x_char[x_char==TRUE])
                        dt[, c(x_char):=lapply(.SD, as.factor), .SDcols=x_char]
                        dt <- data.table(model.matrix(~., data=dt)[, -1])
                        y_prob <- eval(parse(text=pred_func)) # output of probabilities per class
                        y_loss_temp <- cbind(data.table(y_prob), data.table(y_act=dt[, get(y)])) # combine matrix of probabilities for each class
                        y_loss_temp <- sapply(1:dt[, .N], # iterate through each prediction and select only the output with their respective actual class
                                              function(i) {
                                                y_loss_vec <- y_loss_temp[i, get(y_act)]
                                                return(y_loss_vec)
                                              })
                        y_loss <- -sum(log(y_loss_temp))
                        dt <- dt_temp # return original dataset
                        
                        # log-loss based on each randomised permutation for selected variable
                        x_out2 <- lapply(1:n_perm,
                                         function(x2) {
                                           dt_2 <- dt
                                           dt_2[, (x1):=dt_2[sample(x=1:dt_2[, .N], size=dt_2[, .N], replace=FALSE), get(x1)]]
                                           dt_2 <- data.table(model.matrix(~., data=dt_2)[, -1])
                                           y_2_prob <- eval(parse(text=gsub("=dt", "dt_2", pred_func)))
                                           y_2_loss_temp <- cbind(data.table(y_prob), data.table(y_act=dt_2[, get(y)])) # output of probabilities per class
                                           y_2_loss_temp <- sapply(1:dt_2[, .N], # iterate through each prediction and select only the output with their respective actual class
                                                                   function(i) {
                                                                     y_2_loss_vec <- y_2_loss_temp[i, get(y_act)]
                                                                     return(y_2_loss_vec)
                                                                   })
                                           y_2_loss <- -sum(log(y_2_loss_temp))
                                           dt_2 <- data.table(model_name=model_name, iteration=x2, loss_func_diff=y_2_loss-y_loss)
                                           return(dt_2)
                                         })
                        x_out2 <- rbindlist(l=x_out2, use.names=TRUE, fill=TRUE)
                        return(x_out2)
                      } else {
                        return(NULL)
                      }
                    } else if (loss=="sse") { # sums of squares output
                      # sse for model
                      dt_temp <- dt # dummy temp table to replaced by original
                      x_char <- sapply(dt, is.character) # transform character variables to factor, maintain order in model.matrix pivot
                      x_char <- names(x_char[x_char==TRUE])
                      dt[, c(x_char):=lapply(.SD, as.factor), .SDcols=x_char]
                      dt <- data.table(model.matrix(~., data=dt)[, -1])
                      y_pred <- eval(parse(text=pred_func)) # regression predictions
                      y_loss <- sum((dt[, get(y)]-y_pred)^2) # sse
                      dt <- dt_temp # return original dataset
                      
                      # see based on each randomised permutation for each variable
                      x_out2 <- sapply(1:n_perm,
                                       function(x2) {
                                         dt_2 <- dt
                                         dt_2[, (x1):=dt_2[sample(x=1:dt_2[, .N], size=dt_2[, .N], replace=FALSE), get(x1)]]
                                         dt_2 <- data.table(model.matrix(~., data=dt_2)[, -1])
                                         y_2_pred <- eval(parse(text=gsub("=dt", "dt_2", pred_func)))
                                         y_2_pred <- sum((dt_2[, get(y)]-y_2_pred)^2)
                                         dt_2 <- data.table(model_name=model_name, iteration=x12, loss_func_diff=y_2_pred-y_pred)
                                         return(dt_2)
                                       })
                      x_out2 <- rbindlist(l=x_out2, use.names=TRUE, fill=TRUE)
                      return(x_out2)
                    } else {
                      return(NULL)
                    }
                  })
  
  # combine and return results
  x_out1 <- rbindlist(l=x_out1, use.names=TRUE, fill=TRUE)
  return(x_out1)
}