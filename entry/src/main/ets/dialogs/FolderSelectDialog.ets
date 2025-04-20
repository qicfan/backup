import { IBestDialog, IBestLoading, IBestNotify, IBestToast } from "@ibestservices/ibest-ui-v2";
import { BusinessError, deviceInfo } from "@kit.BasicServicesKit"
import { SafeArea } from "../utils/safeArea";
import { AppStorageV2, EditableLeftIconType, EditableTitleBar } from "@kit.ArkUI";
import { WebDav, WebDavResource } from "../utils/webdav";
import { ServerConfig } from "../models/Server";
import { Dialog } from "../utils/dialog";
import { Config } from "../models/Config";

@ComponentV2
export struct FolderSelectDialog {
  @Param rootPath: string = ""
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => new ServerConfig())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => new Config())!;
  @Local safeArea: SafeArea = AppStorageV2.connect(SafeArea, () => new SafeArea(0, 0))!;
  @Local webdav: WebDav = AppStorageV2.connect(WebDav, "webdav", () => new WebDav())!;
  @Local dirList: WebDavResource[] = [];
  @Local path: string[] = []
  @Local init: boolean = true;
  private deviceName = deviceInfo.marketName;

  aboutToAppear() {
    // console.log("folder select dialog open")
    let path = this.rootPath;
    path = path.replace('/' + this.deviceName + '/', '')
    // 如果为空则设置为/
    if (path === "") {
      this.path = ['/']
    } else {
      this.path = path.split('/')
    }
    this.webdav.getDirs(this.path.join('/')).then((rr) => {
      this.dirList = rr.data ? rr.data : [];
      this.init = false;
    }).catch(() => {
      this.init = false;
    })
  }

  changeDir(href: string) {
    IBestToast.showLoading()
    let path = href.split('/');
    if (path[path.length - 1] === '') {
      path.pop()
    }
    this.path = path;
    this.webdav.getDirs(href).then((rr) => {
      // console.log(JSON.stringify(rr))
      this.dirList = rr.data ? rr.data : [];
      IBestToast.hide();
    }).catch(() => {
      IBestToast.hide();
    })

  }
  @Local newDirName: string = ""
  @Local formInputError: boolean = false
  @Local newDirDialog: boolean = false;

  @Builder formInputContain() {
    Column({ space: 20 }) {
      TextInput({ placeholder: '请输入' })
        .onChange(value => {
          this.newDirName = value
          this.formInputError = false
        })
      if (this.formInputError) {
        Text('不能为空')
          .width("100%")
          .textAlign(TextAlign.Start)
          .fontColor(Color.Red)
          .fontSize(12)
      }
    }.padding(20)
  }

  build() {
    Column() {
      EditableTitleBar({
        leftIconStyle: EditableLeftIconType.Back,
        title: '选择保存路径',
        menuItems: [
          {
            value: $r('sys.media.ohos_ic_public_add'),
            isEnabled: true,
            action: () => {
              this.newDirDialog = true;
            }
          }
        ],
        onCancel: () => {
          if (this.path.length <= 1) {
            Dialog.closeDialog();
            return true;
          } else {
            this.path.pop()
            this.changeDir(this.path.join('/'))
            return false;
          }
        },
        onSave: () => {
          let path = this.path.join('/')
          if (!path.endsWith('/')) {
            path += '/';
          }
          path += this.deviceName + '/';
          this.config.backupRootPath = path;
          this.config.update().then(() => {
            // 在服务器上创建目录
            try {
              this.webdav.mkDir(path).then(() => {})
            } catch (error) {
              const err = error as BusinessError;
              IBestNotify.show({
                message: err.message,
                duration: 3000,
                type: 'warning'
              })
            }
            Dialog.closeDialog();
          })
        }
      })
      Column() {
        if(!this.init) {
          List({ space: 20, initialIndex: 0 }) {
            ForEach(this.dirList, (item: WebDavResource) => {
              ListItem() {
                Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Center }) {
                  Image($r("app.media.folder_fill"))
                    .width(24)
                    .height(24)
                    .margin({ right: $r("app.float.inner_padding") })
                    .fillColor($r('app.color.ibest_primary_color'))
                  Text('' + item.displayName)
                    .fontSize(16)
                    .textAlign(TextAlign.Center)
                    .borderRadius(10)
                    .backgroundColor(0xFFFFFF)
                }
                .height(30)
                .width('100%')
              }
              .onClick(() => {
                this.changeDir(item.href)
              })
            }, (item: WebDavResource) => item.href)
          }
          .listDirection(Axis.Vertical) // 排列方向
          .scrollBar(BarState.Off)
          .friction(0.6)
          .edgeEffect(EdgeEffect.Spring) // 边缘效果设置为Spring
          .width('100%')
          .height('100%')
        } else {
          IBestLoading({loadingText: "加载中..."})
        }
      }
      .backgroundColor($r('app.color.ibest_white'))
      .width('100%')
      .layoutWeight(1)
      .borderRadius({ topLeft: 12, topRight: 12 })
      .padding({
        left: $r('app.float.normal_padding'),
        right: $r('app.float.normal_padding'),
        top: $r('app.float.normal_padding')
      })


      Column() {
        Text(`已选路径：${this.path.join('/')}/${this.deviceName}`)
          .fontSize($r("sys.float.ohos_id_popup_text_font_size"))
      }
      .width('100%')
      .height(30)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .padding({
        left: $r('app.float.normal_padding'),
        right: $r('app.float.normal_padding'),
        top: $r('app.float.normal_padding'),
        bottom: $r('app.float.normal_padding')
      })
      .margin({bottom: $r("app.float.normal_padding")})

      IBestDialog({
        visible: this.newDirDialog!!,
        title: "提示",
        showCancelButton: true,
        defaultBuilder: (): void => this.formInputContain(),
        beforeClose: (action) => {
          if (action === 'cancel') {
            return true
          }
          const valueLength = this.newDirName.trim().length
          this.formInputError = !valueLength
          let path = this.path.join('/') + '/' + this.newDirName
          try {
            this.webdav.mkDir(path).then(() => {
              IBestNotify.show({
                message: "已切换到新建的目录",
                duration: 3000,
                type: 'success'
              })
              this.changeDir(path);
            })
          } catch (error) {
            const err = error as BusinessError;
            IBestNotify.show({
              message: err.message,
              duration: 3000,
              type: 'warning'
            })
          }
          return !this.formInputError
        }
      })
    }
    .width('100%')
    .height('80%')
    .borderRadius({ topLeft: 12, topRight: 12 })
    .backgroundColor($r('app.color.ibest_background'))
    .padding({ bottom: px2vp(this.safeArea.bottom) })
  }
}