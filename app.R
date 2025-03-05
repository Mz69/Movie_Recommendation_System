library(shiny)
install.packages(c("shiny", "tidyverse", "recommenderlab", "DT", "shinythemes"))
library(tidyverse)
library(recommenderlab)
library(DT)
library(shinythemes)

# Load Data
ratings <- read.csv("data/ratings.csv") %>% select(userId, movieId, rating)
movies <- read.csv("data/movies.csv") %>% select(movieId, title)

# Convert to a realRatingMatrix format
rating_matrix <- ratings %>%
  pivot_wider(names_from = movieId, values_from = rating) %>%
  select(-userId) %>%
  as.matrix() %>%
  as("realRatingMatrix")

# Build Recommendation Model
rec_model <- Recommender(rating_matrix, method = "UBCF")  # User-based collaborative filtering

# Define UI
ui <- fluidPage(
  theme = shinytheme("cosmo"),
  titlePanel("Movie Recommendation System"),
  
  sidebarLayout(
    sidebarPanel(
      selectInput("movie_input", "Select a Movie:", choices = movies$title),
      actionButton("recommend", "Get Recommendations")
    ),
    
    mainPanel(
      h3("Recommended Movies"),
      DTOutput("rec_table")
    )
  )
)

# Define Server
server <- function(input, output) {
  
  recommend_movies <- eventReactive(input$recommend, {
    selected_movie <- input$movie_input
    movie_id <- movies %>% filter(title == selected_movie) %>% pull(movieId)
    
    # Find similar users who rated this movie
    user_subset <- ratings %>% filter(movieId == movie_id)
    
    if (nrow(user_subset) == 0) {
      return(data.frame(Movie = "No recommendations found", Score = NA))
    }
    
    # Generate recommendations
    top_users <- sample(unique(user_subset$userId), min(5, nrow(user_subset)))  # Select some users
    pred <- predict(rec_model, rating_matrix[top_users, ], n = 5)  # Recommend 5 movies
    
    recommended_movies <- as(pred, "list") %>% unlist() %>% unique()
    recommendations <- movies %>% filter(movieId %in% recommended_movies) %>% select(title)
    
    return(data.frame(Movie = recommendations$title))
  })
  
  output$rec_table <- renderDT({
    datatable(recommend_movies(), options = list(pageLength = 5))
  })
}

# Run App
shinyApp(ui, server)