import { WindowBreakpoint } from "../typing";
import { BreakpointConstants } from "./BreakpointConstants";

@ObservedV2
export class WinBreakpoint implements WindowBreakpoint {
  @Trace currentHeightBreakpoint: string = BreakpointConstants.BREAKPOINT_LG;
  @Trace currentWidthBreakpoint: string = BreakpointConstants.BREAKPOINT_LG;
  @Trace index: number = 0;

  private static _instance: WinBreakpoint | null = null;

  static getInstance() {
    if (WinBreakpoint._instance === null) {
      WinBreakpoint._instance = new WinBreakpoint();
    }
    return WinBreakpoint._instance;
  }
}