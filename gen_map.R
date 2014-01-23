library(rworldmap)

countries <- 
  c("DZA",
    "BHR",
    "EGY",
    "TUN",
    "IRN",
    "YEM",
    "IRQ",
    "JOR",
    "KWT",
    "SYR",
    "LBN",
    "ESH",
    "LBY",
    "MAR",
    "OMN",
    "SAU",
    "QAT",
    "ARE")
country_names <- c(
  "Algeria",
  "Bahrain",
  "Egypt",
  "Tunisia",
  "Iran",
  "Yemen",
  "Islamic Republic of Iraq",
  "Jordan",
  "Kuwait",
  "Syria",
  "Lebanon",
  "Western Sahara",
  "Libyan Arab Jamahiriya",
  "Morocco",
  "Oman",
  "Saudi Arabia",
  "Qatar",
  "United Arab Emirates"
  )
df <- data.frame(country=countries,blah=country_names)
df2 <- joinCountryData2Map(df, joinCode="ISO3",nameJoinColumn="country")

params <- mapCountryData(df2,
                         nameColumnToPlot="blah",
                         mapTitle="",
                         xlim=c(-30,30),
                         ylim=c(-20,40),
                         borderCol=gray(0),
                         catMethod="categorical",
                         colourPalette="rainbow",
                         missingCountryCol=gray(1))

