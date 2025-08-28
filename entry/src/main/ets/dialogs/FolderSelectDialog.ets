import { IBestDialog, IBestLoading, IBestNotify } from "@ibestservices/ibest-ui-v2";
import { BusinessError, deviceInfo } from "@kit.BasicServicesKit"
import { SafeArea } from "../utils/safeArea";
import { AppStorageV2, EditableLeftIconType, EditableTitleBar, EditableTitleBarMenuItem } from "@kit.ArkUI";
import { ServerConfig } from "../models/Server";
import { Dialog } from "../utils/dialog";
import { Config } from "../models/Config";
import { Global } from "../models/Global";
import { ConfigGlobalStatus } from "../typing";
import { BackupServer, DirItem } from "../utils/server";

@ComponentV2
export struct FolderSelectDialog {
  @Param rootPath: string = ""
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local backupServer: BackupServer = AppStorageV2.connect(BackupServer, "BackupServer", () => BackupServer.getInstance())!;
  @Local safeArea: SafeArea = AppStorageV2.connect(SafeArea, () => SafeArea.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local dirList: DirItem[] = [];
  @Local path: string = ""
  @Local init: boolean = true;

  @Local newDirName: string = ""
  @Local formInputError: boolean = false
  @Local newDirDialog: boolean = false;

  private deviceName = deviceInfo.marketName;

  menu: EditableTitleBarMenuItem = {
    value: $r('sys.media.ohos_ic_public_add'), isEnabled: true, action: () => {this.newDirDialog = true;}
  }

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

  aboutToAppear() {
    let path = this.rootPath;
    if (!path) {
      path = ""
    } else {
      path = path.replace('/' + this.deviceName, '')
    }
    this.path = path
    console.log(`已选路径：${this.path}`)
    this.backupServer.dirList(this.path).then((rr) => {
      this.dirList = rr
      this.init = false;
    }).catch(() => {
      this.init = false;
    })
  }

  changeDir(name: string) {
    if (this.path == "") {
      this.path = name
    } else {
      this.path += '/' + name;
    }
    console.log(`切换到路径：${this.path}`)
    this.backupServer.dirList(this.path).then((rr) => {
      this.dirList = rr
    }).catch(() => {
    })
  }
  // 后退目录
  onCancel() {
    if (this.path === "/" || this.path === "") {
      Dialog.closeDialog();
      return true;
    } else {
      // this.path = this.rootPath
      let dl = this.path.split('/')
      dl.pop() // 去掉当前目录
      let name = ""
      if (dl.length >= 1) {
        let n = dl.pop() // 拿到上一级目录的名字
        if (n) {
          name = n
        }
        this.path = dl.join('/') // 当前目录改为上上级目录
      } else {
        name = ""
        this.path = ""
      }

      console.log(`onCancel: ${this.path}`)
      this.changeDir(name)
      return false;
    }
  }

  onSave() {
    let path = this.path
    if (path == "") {
      path = this.deviceName
    } else {
      path += '/' + this.deviceName
    }
    // 在服务器上创建目录
    try {
      this.backupServer.createDir(this.path, this.deviceName).then((resp) => {
        if (!resp || !resp.success || !resp.result) {
          console.warn(`创建目录 ${this.path}/${this.deviceName} 时失败：${resp.message}`)
          return
        }
        let newPath = resp.result.data.path
        if (newPath != "") {
          this.config.backupRootPath = path;
          this.config.update().then(() => {
            this.global.configGlobalStatus = ConfigGlobalStatus.YES;
            Dialog.closeDialog();
          })
        } else {
          IBestNotify.show({
            message: resp.message,
            duration: 3000,
            type: 'warning'
          });
        }
      })
    } catch (error) {
      const err = error as BusinessError;
      IBestNotify.show({
        message: err.message,
        duration: 3000,
        type: 'warning'
      });
    }
  }

  build() {
    Column() {
      Column() {
        EditableTitleBar({
          leftIconStyle: EditableLeftIconType.Back,
          title: '选择保存路径',
          menuItems: [this.menu],
          onCancel: () => {this.onCancel()},
          onSave: () => {this.onSave()}
        })
      }
      Column() {
        if(!this.init) {
          List({ space: 20, initialIndex: 0 }) {
            ForEach(this.dirList, (item: DirItem) => {
              ListItem() {
                Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Center }) {
                  Image($r("app.media.folder_fill"))
                    .width(24)
                    .height(24)
                    .margin({ right: $r("app.float.inner_padding") })
                    .fillColor($r('app.color.ibest_primary_color'))
                  Text('' + item.name)
                    .fontSize(16)
                    .textAlign(TextAlign.Center)
                    .borderRadius(10)
                    .backgroundColor(0xFFFFFF)
                }
                .height(30)
                .width('100%')
              }
              .onClick(() => {
                this.changeDir(item.name)
              })
            }, (item: DirItem) => item.relPath)
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
        if (this.path == "/" || this.path == "") {
          Text(`已选路径：${this.deviceName}`)
            .fontSize($r("sys.float.ohos_id_popup_text_font_size"))
        } else {
          Text(`已选路径：${this.path}/${this.deviceName}`)
            .fontSize($r("sys.float.ohos_id_popup_text_font_size"))
        }
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
          try {
            this.backupServer.createDir(this.path, this.newDirName).then((rs) => {
              if (rs.success) {
                IBestNotify.show({
                  message: "已切换到新建的目录",
                  duration: 3000,
                  type: 'success'
                })
                this.changeDir(this.newDirName);
              } else {
                IBestNotify.show({
                  message: rs.message,
                  duration: 3000,
                  type: 'warning'
                })
              }
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