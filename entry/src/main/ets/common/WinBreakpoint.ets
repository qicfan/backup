import { WindowBreakpoint } from "../typing";
import { BreakpointConstants } from "./BreakpointConstants";

@ObservedV2
export class WinBreakpoint implements WindowBreakpoint {
  @Trace currentHeightBreakpoint: string = BreakpointConstants.BREAKPOINT_LG;
  @Trace currentWidthBreakpoint: string = BreakpointConstants.BREAKPOINT_LG;
  @Trace imageSize: number = 0;
  imagePageSize: number = 20;

  @Trace
  width: number = 0;
  height: number = 0;

  private static _instance: WinBreakpoint | null = null;
  static breakpointCol: Record<string, number> = {
    "xs": 3,
    "sm": 4,
    "md": 6,
    "lg": 8,
    "xl": 8
  }
  static getInstance() {
    if (WinBreakpoint._instance === null) {
      WinBreakpoint._instance = new WinBreakpoint();
    }
    return WinBreakpoint._instance;
  }

  getColumns() {
    if (WinBreakpoint.breakpointCol[this.currentWidthBreakpoint]) {
      return WinBreakpoint.breakpointCol[this.currentWidthBreakpoint]
    } else {
      return 3;
    }
  }

  updateImageSize() {
    const columns = WinBreakpoint.breakpointCol[this.currentWidthBreakpoint];
    this.imageSize = Math.floor((this.width - 24 - (columns * 3)) / columns);
    this.imagePageSize = Math.floor(this.height / this.imageSize * columns) + 10;
  }
}