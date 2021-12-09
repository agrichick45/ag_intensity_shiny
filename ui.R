###############################################################################
#
# This is the UI R script mapping agricultural intensification in the Midwest
#
# Author:  Mandy Liesch
# Email:  amliesch@ncsu.edu
#
###############################################################################
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

#Change the dataset for ggplot
plotDataset<-mergedData

#set up the interactive variables for numeric values
varsX<-as.list(names(plotDataset[7:48]))
#set up the categorical variables
varsY<-as.list(names(plotDataset[4:6]))
#set up the fill vizualization categorical options.
varsZ<-as.list(c(names(plotDataset[5:6]), "NULL"))

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
# Start of Shiny UI
#
###############################################################################

shinyUI( #open Shiny
  navbarPage( 											#open Navbar
    
    
    titlePanel("Agricultural Intensification Rates"),
    #Set up the interactive sidebar panel
    # Create tabs for the different sections.
    tabsetPanel( 											#open tabset
      
      ###############################################################################
      #
      # About Tab
      #
      ###############################################################################
      
      # Create a tab for the About section.
      tabPanel( 												#open tabpanel
        # Add a title.
        title="About",
        # Create a main panel for the About tab.
        mainPanel( 											#open main panel
          includeMarkdown("about.md"),
        ), 													#close main panel
      ), 														#clost tabpanel
      ############################################################################
      #
      # Dynamic Mapping Tab
      #
      ############################################################################
      
      tabPanel(												#open tabpanel
        # Add a title.
        title="Dynamic Maps",
        #Add the leaflet rendered map
        mainPanel(leafletOutput("mymap"),						#open mainpanel			
        )													#close mainpanel
      ),													#close tabPanel
      
      ###############################################################################
      #
      # Interactive ggPlot
      #
      ###############################################################################
      tabPanel(												#open tab panel
        # Add a title.
        title="Interactive ggPlot",
        # Create a side panel
        sidebarLayout(										#open sidebarLayout
          #Create the panel with options
          sidebarPanel(										#open sidebarPanel
            #Create the numeric value inputs
            selectInput('x', 'X', choices = c(varsX),
                        selected = "Adens_Slope"),
            #Set the categorical variable
            selectInput('y', 'Y', choices = c(varsY), 
                        selected = "Megacluster"),
            
            #Choose the optional color data
            selectInput('z', 'Z', choices = c(varsZ), 
                        selected = "Megacluster"),
            
          ),													#close sidebarPanel
          #Display the heatmap and interactive panel
          mainPanel(											#open mainPanel
            plotOutput("outplot")
          ),													#close mainpanel
        ),													#close sidebarLayout
      ),														#close tabpanel
      
      ###############################################################################
      #
      # Interactive Heatplot
      #
      ###############################################################################
      tabPanel(												#open tab panel
        # Add a title.
        title="Interactive Heatplot",
        
        sidebarPanel("Click on the heat plot to zoom.",
                     "Use the plotly bar to zoom or restore.",
                     "Hover and Click for variable relationship"),
        mainPanel(											#open mainPanel
          plotlyOutput("heatmap", width = "100%", height="600px"),
        ),													#close mainpanel
      ),														#close tabpanel
      
      
      ###############################################################################
      #
      # Modeling Tab with Dropdown Tabs
      #
      ###############################################################################
      # Create the Modeling tab with 3 sub-tabs.
      navbarMenu(													#open navbarMenu2
        
        # Add a title.
        title="Modeling",
        ###############################################################################
        #
        # Modeling Info Section
        #
        ###############################################################################
        tabPanel(												#open tabPanel
          # Give it a title,
          title = "Modeling Info",
          mainPanel( 											#open mainPanel
            includeMarkdown("Modeling.md"),
          )												#close mainpanel
        ),													#close tabPanel
        
        ###############################################################################
        #
        # Model Exploration
        #
        ###############################################################################
        
        tabPanel(													#open tabpanel
          # Add a title.
          title="Models",
          # Create a side panel
          sidebarPanel(											#create sidebarPanel
            h3("Choose a Model"
            ),
            #Give conditional model types 
            radioButtons("modelType", 								#open radioButtons
                         label = "Choose a Model:", 
                         choices = c("Single Regression Tree",
                                     "Random Forest",
                                     "Boosting Regression"
                         ), 
                         selected = character(0)
            ),   										#close radio button
            
            
            ###############################################################################
            #
            # Regression Tree Conditional Inputs
            #
            ##############################################################################
            
            #Set the conditional Panel to the Single Regression Tree
            conditionalPanel(condition = "input.modelType == 'Single Regression Tree'",
                             h3("Select Parameters for Fit"							#open Conditionalpanel
                             ),
                             checkboxGroupInput("regTreeVars", 						#open checkboxGroupInput
                                                label = "Check at Least 5 Parameters for Entry in Regression Model",
                                                choices = names(train.tree)[-c(1:3)]
                             ),										#close checkboxGroupInput
                             h3("Select Cross Validation Fit Options"),
                             "A Stratified Training Sample Set of 80% was prepared:",
                             
                             sliderInput("numFolds", 								#open sliderInput
                                         label = "Minimum of 2 Folds, Maximum of 10:",
                                         min = 2, max = 10, value = 5
                             ),										#close sliderInput
                             actionButton("runRegTree", label = "Generate Model"),
            ),														#close Conditionalpanel    
            
            
            ###############################################################################
            #
            # Random Forests Modelling
            #
            ###############################################################################
            
            #Set up the conditional random forests model
            conditionalPanel(condition = "input.modelType == 'Random Forest'",
                             h3("Select Parameters for Fit"),						#open Conditionalpanel
                             
                             checkboxGroupInput("rfVars", 							#open checkboxGroupInput
                                                label = "Select at Least 5 Variables for Random Forests",
                                                choices = names(train.tree)[-c(1:3)]
                             ),										#close checkboxGroupInput
                             h3("Select Tree Fit Options"),
                             
                             
                             sliderInput("numFolds", 								#open sliderInput
                                         label = "Minimum of 2 Folds, Maximum of 10:",
                                         min = 2, max = 10, value = 5
                             ),										#close sliderInput
                             
                             actionButton("runForest", label = "Generate Model")
            ),														#close Conditionalpanel 
            
            
            
            ###############################################################################
            #
            # Boosting Model
            #
            ###############################################################################
            
            #Set up the boosting continual model						#open conditionalPanel
            conditionalPanel(condition = "input.modelType == 'Boosting Regression'",
                             h3("Select Parameters for Fit"),
                             
                             checkboxGroupInput("bagVars", 							#open checkboxGroupInput
                                                label = "Select at Least 5 Variables for Boosting",
                                                choices = names(train.tree)[-c(1:6)]),
                             
                             sliderInput("numFolds", 								#open sliderInput
                                         label = "Minimum of 2 Folds, Maximum of 10:",
                                         min = 2, max = 10, value = 5
                             ),											#close sliderInput
                             
                             actionButton("boostRun", label = "Generate Model")	
                             
            ), 														#close conditionalPanel
          ),															#close sidebarPanel
          
          
          ###############################################################################
          #
          # Main Panel Conditions
          #
          ###############################################################################
          #Set up the conditional display for the main panel
          mainPanel(fluidPage(									#open mainPanel
            conditionalPanel(condition = "input.modelType == 'Single Regression Tree'",
                             htmlOutput("regressTreeTitle"),			#open conditionalPanel
                             h4("Regression Tree Model Fit Summary:"),
                             plotOutput("summary.Tree"),
                             br(),
                             h4("Test Model Fit Statistics:"),
                             verbatimTextOutput("tree.Fit.Stats")
            ),													#close conditionalPanel
            
            #Set the second conditional panel for Random Forests
            conditionalPanel(condition = "input.modelType == 'Random Forest'",
                             htmlOutput("forestTitle"),				#open conditionalPanel
                             h4("Random Forest Model Fit Summary:"),
                             plotOutput("summary.RF"),
                             br(),
                             h4("Test Model Fit Statistics:"),
                             verbatimTextOutput("RFFitStats")
            ),													#close conditionalPanel
            #Set the boosting model conditions
            conditionalPanel(condition = "input.modelType == 'Boosting Regression'",
                             htmlOutput("BoostTitle"),				#open conditionalPanel
                             h4("Boosting Regression:"),
                             tableOutput("summaryBoost"),
                             br(),
                             h4("Test Model Fit Statistics:"),
                             verbatimTextOutput("boostFitStats")
            ),												#close conditionalPanel
          ),													#close fluidPage
          )														#close mainPanel
        ),															#close tabPanel
        
        
        ###############################################################################
        #
        # Model Fitting Section
        #
        ###############################################################################
        
        tabPanel(													#open tabPanel
          # Add a title for the sub tab.
          title = "Model Fitting",
          sidebarPanel(												#open sidebarPanel
            radioButtons("predictionModel", 						#open radioButtons
                         label = "Choose Model:", 
                         choices = c("Single Regression Tree",
                                     "Random Forest",
                                     "Boosted Regression Tree"), 
                         selected = character(0)
            ),													#close radioButtons
          ),														#close sidebarPanel
          
          mainPanel(fluidPage(									#open 2 tabs
            "So, I spend way too much time with the interactive map setups,", 
            "and totally didn't realize this was a requirement. ",
            "So, I have found the way to save the models with the variables", 
            "I chose, but in order to actually create these models, I have", 
            "to process conditionally all 50 variables in my subset.", 
            "Fingers crossed I can get this fixed really soon, but I don't", 
            "want to not pass the course.",
            
            
          ),												#close fluidPage
          ),														#close main panel
        ),															#close tabPanel
      ),																#close Navbar
      ###############################################################################
      #
      # Data Tab
      #
      ###############################################################################
      tabPanel(														#open tabPanel
        # Add a title.
        title="Data",
        # Create a side panel.
        sidebarPanel(													#open sidebarPanel
          # Create a filter for the states of interest.
          selectInput(											#open selectInput
            inputId = "selectedStates",
            label = "Filter by State(s)",
            choices = unique(mergedData$State),
            selected = unique(mergedData$State)
          ),														#close selectInput	
          # Create a filter for the counties by initial intensity.
          selectInput(											#open selectInput
            inputId = "initialIntense",
            label = "Filter by 1997 Agricultural Intensity",
            choices = c("Low", "Medium", "High"),
            selected = c("Low", "Medium", "High"),
          ),														#close selectInput										
          # Create a filter for the counties to display by winner.
          selectInput(											#open selectInput
            inputId = "selectedIntense",
            label = "Filter by Agricultural Intensification",
            choices = c("Low", "Medium", "High"),
            selected = c("Low", "Medium", "High"),
          ),														#close selectInput
          
          # Create a download button to download the data set.
          sidebarPanel(downloadButton("downloadData", "Download"))
        ),													#close sidebarPanel
        
        # Create a main panel for the data tab.
        dataTableOutput(outputId = "tab")							
      ) 														#close tab panel								
      
      #close off all the tabs		
    ) #close tabset
  ) #closes Navbar
) #closes shiny




