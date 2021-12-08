###############################################################################
#
# This is the UI R script mapping agricultural intensification in the Midwest
#
# Author:  Mandy Liesch
# Email:  amliesch@ncsu.edu
#
###############################################################################

###############################################################################
#
# Start of Shiny UI
#
###############################################################################

shinyUI(navbarPage(
  
  
  titlePanel("Agricultural Intensification Rates"),
  #Set up the interactive sidebar panel
  # Create tabs for the different sections.
  tabsetPanel(
    
###############################################################################
#
# About Tab
#
###############################################################################
    
    # Create a tab for the About section.
    tabPanel(
      # Add a title.
      title="About",
      # Create a main panel for the About tab.
      mainPanel( 
        includeMarkdown("about.md"),
      ),
    ),
    ###############################################################################
    #
    # Dynamic Mapping Tab
    #
    ###############################################################################
    
    tabPanel(
      # Add a title.
      title="Dynamic Maps",
      #Add the leaflet rendered map
      mainPanel(leafletOutput("mymap"),
      )),

    ###############################################################################
    #
    # Interactive Heatmap
    #
    ###############################################################################
    tabPanel(
      # Add a title.
      title="Interactive Exploration",
      # Create a side panel
      sidebarLayout(
        #Create the panel with options
        sidebarPanel("Choose which varibales to explore",
          #Create the numeric value inputs
          selectInput('x', 'X', choices = c(varsX),
                      selected = "Adens_Slope"),
          #Set the categorical variable
          selectInput('y', 'Y', choices = c(varsY), 
                      selected = "Megacluster"),
          #Choose the optional color data
          "</br>Would you like to change the chart color? </br>",
          selectInput('z', 'Z', choices = c(varsZ), 
                      selected = "Megacluster"),
          
        ),
        #Display the heatmap and interactive panel
        mainPanel(h3("Interactive Heatmap: Click to Zoom"),
          plotlyOutput("heatmap", width = "100%", height="600px"),
          (h3("Interactive Plot Exploration")),
          plotOutput("outplot")
        ),
      ),
    ),

###############################################################################
#
# Modeling Tab with Dropdown Tabs
#
###############################################################################
# Create the Modeling tab with 3 sub-tabs.
navbarMenu(
  
  # Add a title.
  title="Modeling",
###############################################################################
#
# Modeling Info Section
#
###############################################################################
  tabPanel(
    # Give it a title,
    title = "Modeling Info",
    mainPanel( 
      includeMarkdown("Modeling.md"),
    ))),
  
  ###############################################################################
  #
  # Model Exploration
  #
  ###############################################################################
  
  tabPanel(
    # Add a title.
    title="Models",
    # Create a side panel
    sidebarPanel(
      h3("Choose a Model"
      ),
      #Give conditional model types 
      radioButtons("modelType", 
                   label = "Choose a Model:", 
                   choices = c("Single Regression Tree",
                               "Random Forest",
                               "Boosting Regression"
                   ), 
                   selected = character(0)
      ),   

      
###############################################################################
#
# Regression Tree Conditional Inputs
#
##############################################################################
      #Set the conditional Panel to the Single Regression Tree
      conditionalPanel(condition = "input.modelType == 'Single Regression Tree'",
                       h3("Select Parameters for Fit"
                       ),
                       checkboxGroupInput("regTreeVars", 
                                          label = "Check at Least 5 Parameters for Entry in Regression Model",
                                          choices = names(train.tree)[-c(1:3)]
                       ),
                       h3("Select Cross Validation Fit Options"),
                       "A Stratified Training Sample Set of 80% was prepared:",
                       
                       sliderInput("numFolds", 
                                   label = "Minimum of 2 Folds, Maximum of 10:",
                                   min = 2, max = 10, value = 5
                       ),
                       actionButton("runRegTree", label = "Generate Model"),
      ),    


###############################################################################
#
# Random Forests Modelling
#
###############################################################################
      #Set up the conditional random forests model
      conditionalPanel(condition = "input.modelType == 'Random Forest'",
                 h3("Select Parameters for Fit"
                 ),
                 checkboxGroupInput("rfVars", 
                                    label = "Select at Least 5 Variables for Random Forests",
                                    choices = names(train.tree)[-c(1:3)]
                 ),
                 h3("Select Tree Fit Options"
                 ),
                 
                 sliderInput("numFolds", 
                             label = "Minimum of 2 Folds, Maximum of 10:",
                             min = 2, max = 10, value = 5
                 ),
                 actionButton("runForest", label = "Generate Model")
),



###############################################################################
#
# Boosting Model
#
###############################################################################
      #Set up the boosting continual model
      conditionalPanel(condition = "input.modelType == 'Boosting Regression'",
                 h3("Select Parameters for Fit",
                 ),
                 checkboxGroupInput("bagVars", 
                                    label = "Select at Least 5 Variables for Boosting",
                                    choices = names(train.tree)[-c(1:6)]),
                 
                 sliderInput("numFolds", 
                             label = "Minimum of 2 Folds, Maximum of 10:",
                             min = 2, max = 10, value = 5
                 ),
                 
                 actionButton("boostRun", label = "Generate Model")
                 
),
    ),


###############################################################################
#
# Main Panel Conditions
#
###############################################################################
    #Set up the conditional display for the main panel
    mainPanel(fluidPage(
        conditionalPanel(condition = "input.modelType == 'Single Regression Tree'",
                   htmlOutput("regressTreeTitle"),
                   h4("Regression Tree Model Fit Summary:"),
                   plotOutput("summary.Tree"),
                   br(),
                   h4("Test Model Fit Statistics:"),
                   verbatimTextOutput("tree.Fit.Stats")
      ),
      #Set the second conditional panel for Random Forests
      conditionalPanel(condition = "input.modelType == 'Random Forest'",
                   htmlOutput("forestTitle"),
                   h4("Random Forest Model Fit Summary:"),
                   plotOutput("summary.RF"),
                   br(),
                   h4("Test Model Fit Statistics:"),
                   verbatimTextOutput("RFFitStats")
      ),
      #Set the boosting model conditions
      conditionalPanel(condition = "input.modelType == 'Boosting Regression'",
                   htmlOutput("BoostTitle"),
                   h4("Boosting Regression:"),
                   tableOutput("summaryBoost"),
                   br(),
                   h4("Test Model Fit Statistics:"),
                   verbatimTextOutput("boostFitStats")
  )
))
  ),


###############################################################################
#
# Model Fitting Section
#
###############################################################################

tabPanel(
  # Add a title for the sub tab.
  title = "Model Fitting",
  sidebarPanel(
    radioButtons("predictionModel", 
                 label = "Choose Model:", 
                 choices = c("Single Regression Tree",
                             "Random Forest",
                             "Boosted Regression Tree"), 
                 selected = character(0)
    ),
  ),
  mainPanel(fluidPage(
    "So, I spend way too much time with the interactive map setups,", 
    "and totally didn't realize this was a requirement. <br><br>",
    "So, I have found the way to save the models with the variables", 
    "I chose, but in order to actually create these models, I have", 
    "to process conditionally all 50 variables in my subset. <br>", 
    "Fingers crossed I can get this fixed really soon, but I don't", 
    "want to not pass the course.",
    
    
  ),
  ),
),
  ),
###############################################################################
#
# Data Tab
#
###############################################################################
tabPanel(
  # Add a title.
  title="Data",
  # Create a side panel.
  sidebarPanel(
    # Create a filter for the states of interest.
    selectInput(
      inputId = "selectedStates",
      label = "Filter by State(s)",
      choices = unique(mergedData$State),
      selected = unique(mergedData$State)
    ),
    # Create a filter for the counties by initial intensity.
    selectInput(
      inputId = "initialIntense",
      label = "Filter by 1997 Agricultural Intensity",
      choices = c("Low", "Medium", "High"),
      selected = c("Low", "Medium", "High"),
    ),
    # Create a filter for the counties to display by winner.
    selectInput(
      inputId = "selectedIntense",
      label = "Filter by Agricultural Intensification",
      choices = c("Low", "Medium", "High"),
      selected = c("Low", "Medium", "High"),

    ),
    # Create a download button to download the data set.
    sidebarPanel(downloadButton("downloadData", "Download")
    )
  ),
  # Create a main panel for the About tab.
  dataTableOutput(outputId = "tab")
) 
)
)



