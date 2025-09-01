import { cleanTemp, formatFileSize } from "../utils/tools";
import { statfs } from "@kit.CoreFileKit";
import { IBestButton, IBestCell } from "@ibestservices/ibest-ui-v2";

@ComponentV2
export struct TempClean {

  @Local useCount: number = 0
  @Local loading: boolean = false

  @Builder
  ButtonBuilder() {
    IBestButton({
      text: "清空",
      btnWidth: 90,
      btnHeight: 28,
      btnFontSize: 14,
      type: 'primary',
      disabled: this.loading
    })
      .onClick(() => {
        this.clear()
      })
  }

  aboutToAppear(): void {
    let context = getContext(this)
    let tempDir = context.tempDir + '/'

    statfs.getTotalSize(tempDir).then((used) => {
      this.useCount = used
      console.log(`${tempDir}总用量: ${used}`)
    })
  }

  clear() {
    this.loading = true
    let context = getContext(this)
    let tempDir = context.tempDir + '/'
    cleanTemp(tempDir).then(() => {
      this.loading = false
    })
  }

  build() {
    IBestCell({
      title: "临时目录用量: " + formatFileSize(this.useCount),
      valueBuilder: (): void => this.ButtonBuilder()
    })
      .margin({
        bottom: $r('app.float.normal_padding'),
        left: $r('app.float.normal_padding'),
        right: $r('app.float.normal_padding')
      })
  }
}