import { Controller } from "@hotwired/stimulus"

// Manual allocation: one select holds "lotId:locationId", copied into the two hidden form fields.
export default class extends Controller<HTMLFormElement> {
  static targets = ["lot", "location"]
  declare readonly lotTarget: HTMLInputElement
  declare readonly locationTarget: HTMLInputElement

  choose(event: Event): void {
    const value = (event.target as HTMLSelectElement).value
    const [lotId, locationId] = value.split(":")
    this.lotTarget.value = lotId ?? ""
    this.locationTarget.value = locationId ?? ""
  }
}
