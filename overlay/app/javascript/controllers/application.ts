import { Application } from "@hotwired/stimulus"

const application = Application.start()
application.debug = false
;(window as unknown as { Stimulus: Application }).Stimulus = application

export { application }
