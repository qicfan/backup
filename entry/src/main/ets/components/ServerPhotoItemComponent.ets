import { AppStorageV2 } from '@kit.ArkUI';
import { WinBreakpoint } from "../common/WinBreakpoint";
import { IBestSkeletonParagraph } from "@ibestservices/ibest-ui-v2";
import { Global } from "../models/Global";
import { BackupServer, ServerPhotoItem } from "../utils/server";
import { image } from "@kit.ImageKit";

@ComponentV2
export struct ServerPhotoItemComponent {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @Param serverPhotoItem: ServerPhotoItem | null = null;
  @Param index: number = 0;
  @Local isDelete: boolean = false;
  @Local thumbnail: PixelMap | undefined = undefined;
  @Local winBP: WinBreakpoint =
    AppStorageV2.connect(WinBreakpoint, 'windowBreakpoint', () => WinBreakpoint.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local backupServer: BackupServer = AppStorageV2.connect(BackupServer, "BackupServer", () => BackupServer.getInstance())!;
  @Local imageTypeRes: string = "";
  @Local imageStatusIcon: string = "";
  @Local progress: number = 0;
  @Local progressY: number = 100;

  private is: image.ImageSource | undefined

  async aboutToAppear() {
    if (this.serverPhotoItem === null ) {
      // console.warn(`${this.serverPhotoItem?.path} 的缩略图不正常: ${this.serverPhotoItem?.thumbnail}`)
      return
    }
    let ctx = getContext(this)
    this.serverPhotoItem.thumbnail =
      await this.backupServer.getThumbnailUrl(ctx, this.serverPhotoItem.path, `${this.winBP.imageSize}x${this.winBP.imageSize}`)
    // 将图片转成PixelMap
    // console.log('下载缩略图完成，缩略图：' + this.serverPhotoItem.thumbnail)
    // 获取缩略图路径
    let i = 0
    let si = setInterval(() =>{
      if (this.serverPhotoItem === null) {
        clearInterval(si)
        return
      }
      try {
        this.is = image.createImageSource(this.serverPhotoItem.thumbnail)
        // console.log('根据路径生成ImageSource成功: ' + this.serverPhotoItem.thumbnail)
      } catch (e) {
        console.error(`根据路径生成imageSource出错:${this.serverPhotoItem.thumbnail}, 错误:${e.message}`)
      }
      i++
      if (this.is !== undefined) {
        try {
          this.is?.createPixelMap().then((pm: PixelMap) => {
            this.thumbnail = pm
            this.is?.release()
          })
          // console.log(`根据imageSource生产PixelMap成功：${this.serverPhotoItem.thumbnail} => ${this.thumbnail}`)
        } catch (e) {
          // console.error(`根据imageSource生成PixelMap出错:${this.serverPhotoItem.thumbnail}, 错误:${e.message}`)
        }
        // console.log(`成功生成imageSource，跳出循环：${this.serverPhotoItem.path}`)
        clearInterval(si)
        return
      }
      if (i > 10) {
        console.error(`重试 ${i} 次后依然无法生成imageSource，跳出循环`)
        clearInterval(si)
        return
      }
    }, 100)
    this.updateIcon();
  }

  aboutToDisappear(): void {
    this.thumbnail?.release()
  }

  updateIcon() {
    if (this.serverPhotoItem === null) {
      return
    }
    if (this.serverPhotoItem.type === 1) {
      this.imageTypeRes = "app.media.picture_fill"
    }
    if (this.serverPhotoItem.type === 3) {
      this.imageTypeRes = "app.media.livephoto"
    }
    if (this.serverPhotoItem.type === 2) {
      this.imageTypeRes = "app.media.dot_video_fill"
    }
  }

  build() {
    Stack() {
      if (!this.isDelete) {
        if (this.thumbnail !== undefined) {
          Image(this.thumbnail).width(this.winBP.imageSize).height(this.winBP.imageSize).objectFit(ImageFit.Cover)
            .geometryTransition(this.serverPhotoItem?.id + '')
        } else {
          IBestSkeletonParagraph({type: "image", rowWidth: this.winBP.imageSize, rowHeight: this.winBP.imageSize})
        }
      } else {
        Column() {
          Text("已删除")
        }
        .width(this.winBP.imageSize).height(this.winBP.imageSize)
        .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
      }
      Row() {
        Image($r(this.imageTypeRes)).width(18).height(18)
      }
      .width('100%')
      .height(28)
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)
      .position({x: 2, y: 0})
    }
    .width(this.winBP.imageSize).height(this.winBP.imageSize)
    .onClick(() => {
      animateTo({
        duration: 350,
        curve: Curve.Friction
      }, () => {
        this.pageInfos.pushPathByName("serverItemDetail", this.serverPhotoItem);
      })

    })
  }
}