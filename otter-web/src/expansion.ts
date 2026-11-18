import type { JsonObject } from "./types"

export type HostAction = (params: JsonObject | undefined) => void
export type PageOpener = (page: string) => void

class ExpansionCenterImpl {
  pageOpener: PageOpener | null = null
  private actions = new Map<string, HostAction>()

  registerPageOpener(opener: PageOpener | null) {
    this.pageOpener = opener
  }

  registerHostAction(name: string, action: HostAction) {
    this.actions.set(name, action)
  }

  unregisterHostAction(name: string) {
    this.actions.delete(name)
  }

  dispatchHost(name: string, params: JsonObject | undefined): boolean {
    const action = this.actions.get(name)
    if (!action) return false
    action(params)
    return true
  }
}

export const ExpansionCenter = new ExpansionCenterImpl()
