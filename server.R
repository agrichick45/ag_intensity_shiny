##############################################
# Measuring Rural Intensification in R -- 
# A Shiny Project
# 
# Fall 2021
# Mandy Liesch
# amliesch@ncsu.edu
# 
##############################################

library(leaps)
library(dplyr)
library(shiny)
library(shinyWidgets)
library(shinythemes)
library(mapdeck)
library(markdown)
library(ggplot2)
library(rjson)
library(jsonlite)
library(leaflet)
library(RCurl)
library(rgeos)
library(maptools)
library(leaflet)
library(htmltools)
library(shiny)
library(plotly)
library(shiny)
library(tidyverse)
library(caret)
library(rsample)
library(rpart)	
library(rpart.plot)
library(png)
library(summarytools)
library(rattle)
library(gbm)
library(stringr)
library(ggridges)
library(shiny)
library(shinyWidgets)
library(DT)
library(readr)
library(tidyverse)
library(imager)
library(plotly)
library(caret)
library(rattle)
library(processx)


##############################################
# 
#  Data Environment Setup
# 
##############################################

# Set the file name.
dataPath1 <- "./Data/mergedData.csv"
dataPath2 <- "./Data/agIntenSlope.csv"

## Read in the full Dataset.
mergedData <- read_csv(dataPath1, col_types=cols())

## Remove all NA from the full dataset with zero
mergedData[is.na(mergedData)]<-0

#Convert factors to Factors
mergedData$NCHS_URCS_2013<-as.factor(mergedData$NCHS_URCS_2013)
mergedData$InitialCluster<-as.factor(mergedData$InitialCluster)
mergedData$Megacluster<-as.factor(mergedData$Megacluster)

# Read in the second data file
agIntenSlope <- read_csv(dataPath2, col_types=cols())

# Remove all NAs with Zeros
agIntenSlope[is.na(agIntenSlope)]<-0

#Load in the GIS Shapefile for dynamic models
countyData<-readShapeSpatial("countyshape.shp")

##############################################
# 
#  ggPlot Setup
# 
##############################################

#Change the dataset for ggplot
plotDataset<-mergedData
data(plotDataset)
#set up the interactive variables for numeric values
varsX<-names(plotDataset[7:48])
#set up the categorical variables
varsY<-names(plotDataset[4:6])
#set up the fill vizualization categorical options.
varsZ<-c(names(plotDataset[5:6]), "NULL")

###############################################################################
#
# Map and Leaflet Setup
#
###############################################################################

#Create the tag for the Title
MapInfo <- tags$p(tags$style("<p {font-size:12px} />"),
                  tags$b("Agricultural Intensification: Rate of Change (Slope)"))

#Merge the Intensification Shapefile with the Geospatial Data Frame
dataMap<-merge(countyData, agIntenSlope, by.x="GEOID_1", by.y="GEOID")

#Create the interactive popup.
popup <- paste0("<strong>", dataMap$NAME, "</strong><br /> 
            Total Market Value: $", dataMap$totMarkSlope, "<br />
            Operations with Income > $500,000: ", dataMap$opgr500kSlope,  "<br /> Farms > 2000 Acres: ",
                dataMap$slopelargeCropOp, "<br /> Animal Density: ", dataMap$Adens_Slope, "<br />
            Percent of Sales > $500,000: ",
                dataMap$perMarkSlope)

####################################################
#
#  Interactive Heatmap Setup
#
####################################################
#Manipulate data for dynamic correlation model
trimData<-mergedData[7:48]
cmat<-cor(trimData)

#Set up the interactive heatmap figure
fig <- plot_ly(
  x = c(colnames(cmat)), y = c(row.names(cmat)),
  z = cmat, type = "heatmap"
)


####################################################
#
#  Training and Testing Datasets
#
####################################################

#Remove the Cropland Loss Parameter
mergedData$PerCroplandLoss<-NULL

#Create an index partition for an 80% test, 20% train
index <- createDataPartition(mergedData$PerCroplandGain,
            p = 0.8, list = FALSE, times = 1)

#Output the training and test datasets
train.tree <- mergedData[ index,]
test.tree  <- mergedData[-index,]

###############################################################################
#
# Server Shiny Backend Function
#
###############################################################################


server <- function(input,output, session){

###############################################################################
#
# Mapping Tab
#
###############################################################################
  
  dataSet <- reactive({
    data=dataMap
    selectClass<-input$SB
  })  
  output$mymap <- renderLeaflet({
    #set the color pallet to the Animal Density Increases
    pal <- colorNumeric(palette = "Reds", domain = dataMap$Adens_Slope, na.color = NA)
    #Setup the leaflet plot with the dataMap spatial data frame
    dataMap %>%
      # Interactive mapping package
      leaflet(width = "100%") %>% 
      # Changes base map
      addProviderTiles(provider = "CartoDB.Positron") %>% 
      # Zoom in to this view
      setView(-81.110757, 38.712046, zoom = 4) %>%
      #Add the shapefile
      addPolygons(  
        #Add the popup from previous input
        popup = ~ popup,
        stroke = FALSE,
        smoothFactor = 0,
        fillOpacity = 0.8,
        #Load the color pallet
        color = ~ pal(Adens_Slope)) %>%
      #Add the legend on the map
      addLegend("bottomright", 
                pal = pal, 
                values = ~ totMarkSlope,
                title = "Animal Stocking Density:",
                "Rate of Change",
                opacity = 1) %>%
      #Add the title information
      addControl(MapInfo, position = "topright")
    
  })
###############################################################################
#
# Heatmap Tab
#
###############################################################################
  
  #Output the dynamic heatmap
  output$heatmap <- renderPlotly({
    plot_ly(x = c(colnames(cmat)), 
            y = c(row.names(cmat)), 
            z = cmat, colors = "Reds", 
            type = "heatmap")})
  
###############################################################################
#
#  Interactive ggPlot ridge map functions 
#
###############################################################################
    #Add the output plot statement
    output$outplot <- renderPlot({
    #Plot the dynamic ridge plot with 30% transparancy
    ggplot(plotDataset, aes_string(x = input$x, y= input$y, fill=input$z)) +
      geom_density_ridges(alpha = 3/10) +
      theme_ridges() + 
      theme(legend.position = "right")
  })
  
###############################################################################
#
#  Regression Tree Conditional Panels
#
###############################################################################

  #set up the interactive button to the training model function.
  trainRegTreeModel <- eventReactive(input$runRegTree, {
    
    # Create a Progress object
    progress <- Progress$new()
    #Close processes
    on.exit(progress$close())
    # Set the message to the user while cross-validation is running.
    progress$set(message = "This one is fast Don't Sleep...")
                 
    # check boxes return a list of selected variables, unlist it.
    vars <- unlist(input$regTreeVars)
    
    # Fit a Regression Tree Model using caret cross validation
    # Create a training control baseline with user imported folds
    train.control <- trainControl(method = "cv", number = input$numFolds)
    
    #Set the fit model, looking at Percent Cropland Gain
    tree.Fit <- train(PerCroplandGain ~ .,
                      #Guarentee the y variable is in the model, along with inputs
                      data = train.tree[,c(c("PerCroplandGain"), vars)],
                      #Select regression tree
                      method = 'rpart',
                      trControl = train.control,
                      #Most of the NAs should be gone, but just in case
                      na.action = na.exclude)
    
    # Save the fitted model into the folder to call on the prediction tab.
    saveRDS(tree.Fit, "./Models/reg-tree-model.rds")
    
    #save the output string into a list, queing up the fancy rattle plot
    tree.Plot<- "tree.Fit <- readRDS('./Models/reg-tree-model.rds'); 
                    rattle::fancyRpartPlot(tree.Fit$finalModel)"
    
    #Calculate the prediction and residuals
    tree.yhat <- predict(tree.Fit, newdata = test.tree)
    
    #Calculate the RMSE fit statistics
    tree.Fit.Stats <- mean((tree.yhat-test.tree$PerCroplandGain)^2)
    
    # Output comes in two parts, visual/summary, and fit Statistics
    list(summary = tree.Plot, fitStats = tree.Fit.Stats)
  })
  
  #Output the text portion
  output$treeTitle <- renderUI({
    trainRegTreeModel()
    h5(strong("Regression Tree Model Complete."))
  })
  
  #Output the plot summaries
  output$summary.Tree <- renderPlot({
    eval(parse(text=trainRegTreeModel()$summary))
  })
  
  #Output the Root Mean Square Error Value
  output$tree.Fit.Stats <- renderPrint({
    trainRegTreeModel()$fitStats
  })
  
###############################################################################
#
#  Random Forests Conditional Panels
#
###############################################################################

  #set up the interactive button to the training model function.
  trainRFModel <- eventReactive(input$runForest, {
    
    # Create a Progress object
    progress <- Progress$new()
    # closes progress
    on.exit(progress$close())
    # Set the message to the user while cross-validation is running.
    progress$set(message = "Random Forests Take Forever",
                 detail = "I recommend a beer...")
    
    # check boxes return a list of selected variables, unlist it.
    vars <- unlist(input$rfVars)
    
    # Fit a Random Forest Model using cross validation
    #Set the training control function
    train.control <- trainControl(method = "cv", number = input$numFolds)
    #keeping the y variable in, run the random forests
    rfFit <- train(PerCroplandGain ~ ., 
                   data = train.tree[,c(c("PerCroplandGain"), vars)],
                   method = 'rf',
                   # Return the improtance variable 
                   importance = TRUE,
                   trControl = train.control, 
                   #Plan for the NA scenario
                   na.action = na.exclude)
    
    # Save the fitted model in a folder.
    saveRDS(rfFit, "./Models/rf-model.rds")
    
    #Pull ou the variable importance plot
    import <- varImp(rfFit)
    #Grab the variable names and number for plotting
    importPlot <- as_tibble(import$importance, rownames = "var")
    
    #Sort the values by importance
    importance <- importPlot %>% arrange(desc(Overall))
    
    # Create a plot with the top ten variables
    rfImpPlot <- ggplot(importance[1:10,],
                        aes(x = reorder(var, Overall), 
                            y = Overall, fill = Overall)) +
      geom_col() +
      coord_flip() +
      theme(legend.position = "none") +
      labs(x = "Variables",  
           y = "RF Importance", 
           title ="Importance of Top 10 Variables")
    
    # Calculate the prediction differences
    rf.yHat <- predict(rfFit, newdata = test.tree)
    #Calculate the RMSE for the model
    rf.Stats <- mean((rf.yHat-test.tree$PerCroplandGain)^2)
    
    # Return output as a list 
    list(summary = rfImpPlot, fitStats = rf.Stats)
  })
  
  #Output the title line
  output$forestTitle <- renderUI({
    trainRFModel()
    h5(strong("Random Forests Finished!"))
  })
  
  #Plot the important variables.   
  output$summary.RF <- renderPlot({
    trainRFModel()$summary
  })
  
  #output the RMSE
  output$RFFitStats <- renderPrint({
    trainRFModel()$fitStats
  })
  
###############################################################################
#
#  Boosted Tree Conditional Panels
#
###############################################################################
  
  
  #set up the interactive button to the training model function.
  trainBoostedModel <- eventReactive(input$boostRun, {
    # Create a Progress object
    progress <- Progress$new()
    #close up the progress tab
    on.exit(progress$close())
    # Set the message to the user while cross-validation is running.
    progress$set(message = "Also takes time... Find Chocolate?") 

    # Unlist the boosting values
    vars <- unlist(input$bagVars)
    
    
    # Fit a boosted Regression Model
    Boost.model <- gbm(PerCroplandGain~. , 
                       data = train.tree[,c(c("PerCroplandGain"), vars)],
    ) 
    
    saveRDS(Boost.model, "./Models/boosted-tree.rds")
    
    
    summBoost<- summary(Boost.model)
    importPlot <- as_tibble(summBoost)
    
    boost.yhat <- predict(Boost.model, newdata = test.tree)
    boost.Fit.Stats <- mean((boost.yhat-test.tree$PerCroplandGain)^2)
    
    list(summary = importPlot, fitStats = boost.Fit.Stats)
    
  })
  
  output$BoostTitle <- renderUI({
    trainBoostedModel()
    h5(strong("Model training is complete."))
  })
  
  output$summaryBoost <- renderTable({
    eval(parse(text=trainBoostedModel()$summary))
  })
  
  output$boostFitStats <- renderPrint({
    trainBoostedModel()$fitStats
  })
  
  
  

} #Close the output server model