import { Controller } from "@hotwired/stimulus"

// Success messages fade out by themselves; errors stay until the page changes.
export default class extends Controller<HTMLElement> {
  static targets = ["message"]
  declare readonly messageTargets: HTMLElement[]

  connect(): void {
    window.setTimeout(() => {
      for (const el of this.messageTargets) el.remove()
    }, 6000)
  }
}
