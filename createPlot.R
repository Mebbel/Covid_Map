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
# ToDos ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Animate the plot
# Cluster by incidence rate pattern within county / across counties

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Packages  ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

library(odbc)
library(DBI)
library(RMySQL)

library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)


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
# # Number of Bundesl?nder (BL)
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


# Calculate weekly change in cases
latest_ID_REQUEST = max(rki_landkreis$ID_REQUEST, na.rm = T)

data_plot_landkreis <- 
  rki_landkreis %>% 
  filter(ID_REQUEST == latest_ID_REQUEST | ID_REQUEST == (latest_ID_REQUEST - 7)) %>%
  select(ID_REQUEST, BL, county, EWZ, cases7_per_100k) %>%
  group_by(BL, county) %>%
  pivot_wider(names_from = ID_REQUEST, values_from = cases7_per_100k) %>%
  rename(
    cases_today = as.character(latest_ID_REQUEST),
    cases_last_week = as.character(latest_ID_REQUEST - 7)
  ) %>%
  mutate(
    cases_rel_change = (cases_today / if_else(cases_last_week == 0, 1, cases_last_week) - 1)
  ) %>% ungroup()


# Filter to large counties
data_plot_landkreis <- 
  data_plot_landkreis %>%
  filter(EWZ > 100000)

# ToDo: Mark "Landeshauptstadt"

set.seed(123456) # Seed for geom_jitter
data_plot_landkreis %>%
  ggplot(aes(x = factor(BL, levels = sort(unique(BL), decreasing = TRUE)), y = cases_today)) + 
  theme_classic() + 
  geom_hline(yintercept = c(35, 50, 100), color = c("#649B3F", "#000032", "#CC0000"), size = 1) +
  geom_jitter(aes(size = EWZ, color = cases_rel_change)) + 
  coord_flip() + 
  labs(title = "Covid Incidence Rate by Bundesland and County",
       subtitle = paste0("As of: ", latest_date),
       caption = "Data Source: Robert Koch-Institut (RKI)"
       ) + 
  xlab(element_blank()) +
  ylab("Average number of cases per 100.000 Inhabitants over the last 7 days") + 
  theme(
    panel.grid.major.y = element_line(color = "grey50", size = 0.5, linetype = "solid")
    ) + 
  scale_y_continuous(labels = comma) +
  scale_color_steps2(labels = percent, name = "Relative change", low = "#649B3F", mid = "white", high = "#CC0000", limits = c(-0.3, 0.3), midpoint = 0) +
  scale_size(labels = comma, name = "Population") +
  guides()

# Save the plot
ggsave(paste0("./plots/", "Case_Incidence_by_County_", gsub("-", "_", as.character(latest_date)), ".png"), width = 13, height = 9, dpi = 300)



# Plot over time for largest counties
data_plot_landkreis_t <- 
  rki_landkreis %>%
  select(BL, county, last_update, cases7_per_100k) %>%
  filter(county %in% sort(data_plot_landkreis$county)) %>%
  # filter(BL == "Bayern") %>% #, county == "SK MÃ¼nchen"
  group_by(BL, last_update) %>%
  mutate(ymin = quantile(cases7_per_100k, 0.05), ymax = quantile(cases7_per_100k, 0.95)) %>%
  mutate(last_update = as.Date(last_update, format = "%d.%m.%Y, %H:%M Uhr"))

data_plot_landkreis_t %>%
  ggplot(aes(x = last_update, y = cases7_per_100k, group = county)) + 
  theme_classic() + 
  geom_ribbon(aes(ymin = ymin, ymax = ymax), fill = "grey80", color = "white", alpha = 0.2) +
  geom_line(alpha = 0.2, color = "#000032") +
  # Highlight cities of interest in each BL
  geom_line(
    data = data_plot_landkreis_t %>% 
      filter(county %in% 
               c("SK Stuttgart", "SK München", "SK Berlin Mitte", "SK Potsdam", 
                 "SK Bremen", "SK Wiesbaden", "SK Rostock",
                 "Region Hannover", "SK Düsseldorf", "SK Mainz", "LK Stadtverband SaarbrÃ¼cken",
                 "SK Dresden", "SK Magdeburg", "SK Kiel", "SK Erfurt"
                 )), 
    color = "red") +
  facet_wrap(. ~ BL) +
  xlab(element_blank()) +
  ylab("Average number of cases per 100.000 Inhabitants over the last 7 days") +
  labs(title = "Covid Incidence Rate by Bundesland and County",
       subtitle = paste0("As of: ", latest_date),
       caption = "Data Source: Robert Koch-Institut (RKI)"
  )

# Save the plot
ggsave(paste0("./plots/", "Case_Incidence_by_County_over_time", gsub("-", "_", as.character(latest_date)), ".png"), width = 13, height = 9, dpi = 300)

















