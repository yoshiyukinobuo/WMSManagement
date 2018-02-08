import { Controller } from "@hotwired/stimulus"

// Receiving form: only offer locations whose zone satisfies the lot's required temperature band (FR-R3).
// Choosing an item pre-fills its required temperature type and unit.
export default class extends Controller<HTMLFormElement> {
  static targets = ["type", "location", "unit"]
  declare readonly typeTarget: HTMLSelectElement
  declare readonly locationTarget: HTMLSelectElement
  declare readonly unitTarget: HTMLInputElement
  declare readonly hasUnitTarget: boolean

  connect(): void {
    this.filter()
  }

  filter(): void {
    const required = this.typeTarget.value
    for (const option of Array.from(this.locationTarget.options)) {
      const zoneType = option.dataset.zoneType
      const compatible = !zoneType || required === "" || zoneType === required
      option.hidden = !compatible
      option.disabled = !compatible
    }
    if (this.locationTarget.selectedOptions[0]?.disabled) {
      this.locationTarget.value = ""
    }
  }

  itemChanged(event: Event): void {
    const select = event.target as HTMLSelectElement
    const option = select.selectedOptions[0]
    if (!option) return
    if (option.dataset.requiredType) this.typeTarget.value = option.dataset.requiredType
    if (option.dataset.unit && this.hasUnitTarget) this.unitTarget.value = option.dataset.unit
    this.filter()
  }
}
