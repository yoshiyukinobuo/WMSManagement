import { application } from "./application"

import FlashController from "./flash_controller"
import LocationFilterController from "./location_filter_controller"
import PrintController from "./print_controller"
import SearchController from "./search_controller"
import StockChoiceController from "./stock_choice_controller"

application.register("flash", FlashController)
application.register("location-filter", LocationFilterController)
application.register("print", PrintController)
application.register("search", SearchController)
application.register("stock-choice", StockChoiceController)
