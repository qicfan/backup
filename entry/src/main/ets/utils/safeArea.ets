@ObservedV2
export class SafeArea {
  top: number = 0;
  bottom: number = 0;
  width: number = 0;
  height: number = 0;
  @Trace imageSize: number = 0;

  private static _instance: SafeArea | null = null;

  static getInstance(): SafeArea {
    if (SafeArea._instance === null) {
      SafeArea._instance = new SafeArea();
    }
    return SafeArea._instance;
  }
}