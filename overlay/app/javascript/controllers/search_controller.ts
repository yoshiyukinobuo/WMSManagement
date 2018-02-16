import { Controller } from "@hotwired/stimulus"

// Debounced auto-submit for filter forms. Works when attached to the <form> or to a control inside it.
export default class extends Controller<HTMLElement> {
  static values = { delay: { type: Number, default: 300 } }
  declare delayValue: number
  private timer?: number

  queue(): void {
    window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.submit(), this.delayValue)
  }

  submit(): void {
    const form = this.element instanceof HTMLFormElement ? this.element : this.element.closest("form")
    form?.requestSubmit()
  }

  disconnect(): void {
    window.clearTimeout(this.timer)
  }
}
