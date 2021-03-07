#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
# Visual inspection of the Covid Data
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Notes ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# The RMySQL uses an old authentication method. We need to change the authentication method on the MySQL Server or the Read_User.
# Reference: https://stackoverflow.com/questions/54099722/how-to-connect-r-to-mysql-failed-to-connect-to-database-error-plugin-caching

# ALTER USER 'username'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password'


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Packages  ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

library(odbc)
library(DBI)
library(RMySQL)

library(dplyr)
library(ggplot2)
library(ggrepel)


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Settings ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Set the working directory
# Will only work when the file is sourced (https://stackoverflow.com/questions/1815606/determine-path-of-the-executing-script)
setwd(dirname(sys.frame(1)$ofile))


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Connect to DB ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

dbconn = dbConnect(MySQL(), user = 'Read_User', password = '123456', dbname = 'rki_covid', host = 'localhost')

dbListTables(dbconn)


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Read data ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

rki_landkreis <- DBI::dbGetQuery(dbconn, "SELECT * FROM rki_landkreis")


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Inspect data ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# summary(rki_landkreis)
# 
# # Number of counties (county)
# length(unique(rki_landkreis$county)) #412 -> that is a bit much.
# 
# # Number of Bundesländer (BL)
# length(unique(rki_landkreis$BL)) # 16 -> that's a good number
# 
# # Get the largest counties by Bundesland
# rki_landkreis %>%
#   filter(ID_REQUEST == max(ID_REQUEST)) %>%
#   group_by(BL) %>%
#   arrange(desc(EWZ)) %>% # EWZ -> Einwohnerzahl of county
#   filter(row_number() == 1) %>%
#   select(BL, county, EWZ, cases7_per_100k)



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Create Graphics ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

latest_date <- rki_landkreis[rki_landkreis$ID_REQUEST == max(rki_landkreis$ID_REQUEST), ]$last_update[1]

# Format Date
latest_date <- as.Date(latest_date, format = "%d.%m.%Y, %H:%M Uhr")



# For latest data
data_plot_landkreis <- 
  rki_landkreis %>%
  filter(ID_REQUEST == max(ID_REQUEST)) %>%
  filter(EWZ > 100000)

# Subset to largest cities in each county to add labels
data_plot_landkreis_largest_county <- 
  data_plot_landkreis %>%
  group_by(BL) %>%
  arrange(desc(EWZ)) %>%
  filter(row_number() <= 2) %>%
  mutate(label = paste0(county, " (", cases7_per_100k, ")"))

data_plot_landkreis %>%
  ggplot(aes(x = factor(BL, levels = sort(unique(BL), decreasing = TRUE)), y = cases7_per_100k)) + 
  theme_classic() + 
  geom_hline(yintercept = c(35, 50, 100), color = c("green", "blue", "red"), size = 1) +
  geom_point(aes(size = EWZ), color = rgb(0,0,50, maxColorValue = 255)) + 
  geom_label_repel(
    data = data_plot_landkreis_largest_county, 
    aes(label = label),
    box.padding   = 0.1, 
    point.padding = 0.75,
    segment.color = 'grey50') +
  coord_flip() + 
  labs(title = "Covid Incidence Rate by Bundesland and County",
       subtitle = paste0("As of: ", latest_date),
       caption = "Data Source: Robert Koch-Institut (RKI)"
       ) + 
  xlab(element_blank()) +
  ylab("Average number of cases per 100.000 Inhabitants over the last 7 days") + 
  theme(
    panel.grid.major.y = element_line(color = "grey50", size = 0.5, linetype = "solid"),
    legend.position = "none"
    )

# Save the plot
ggsave(paste0("./plots/", "Case_Incidence_by_County_", gsub("-", "_", as.character(latest_date)), ".png"), width = 13, height = 9, dpi = 300)






















