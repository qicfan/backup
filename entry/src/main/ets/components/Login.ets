import { ServerConfig } from "../models/Server";
import { AppStorageV2 } from "@kit.ArkUI";
import { IBestButton, IBestField, IBestNotify } from "@ibestservices/ibest-ui-v2";
import { WebDav } from "../utils/webdav";
import { BusinessError } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";
import { LoginStatus } from "../typing";
import { url } from "@kit.ArkTS";

@ComponentV2
export struct Login {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack()
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  @Local webdav: WebDav = AppStorageV2.connect(WebDav, "webdav", () => WebDav.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local addBtnLoading: boolean = false;
  // @Local serverPath: string = "/"
  @Local serverHost: string = "192.168.1.1"
  @Local serverPort: string = "12334"
  @Local username: string = "admin"
  @Local password: string = "admin"

  pop: boolean = false;

  async addServer() {
    this.pop = this.pageInfos.getParamByIndex(1) as boolean;
    // 判断数据是否为空
    if (this.serverHost === '' || this.serverPort === '' || this.username === '' || this.password === '') {
      IBestNotify.show({
        message: '请输入服务器、用户名、密码。',
        duration: 3000,
        type: 'warning'
      })
      return
    }
    this.addBtnLoading = true
    console.log(`${this.serverHost}, ${this.serverPort}`)
    this.server.server = `http://${this.serverHost}:${this.serverPort}}`;
    this.server.username = this.username;
    this.server.password = this.password;
    this.webdav.updateSerConfig(this.server);
    const rs = await this.webdav.valid();
    console.log(JSON.stringify(rs));
    if (rs.statusCode !== 200) {
      IBestNotify.show({
        message: rs.message,
        duration: 3000
      })
      this.addBtnLoading = false
      return;
    }
    // 写入服务器到关键资产
    try {
      await this.server.addOrUpdateAsset(this.server.server, this.username, this.password);
      this.addBtnLoading = false
      this.global.loginStatus = LoginStatus.LOGIN;
      this.pageInfos.pop();
    } catch (error) {
      let err = error as BusinessError;
      IBestNotify.show({
        message: err.message,
        duration: 3000
      })
      this.addBtnLoading = false
      console.error(`Failed to updated Asset. Code is ${err.code}, message is ${err.message}`);
    }

    return
  }

  aboutToAppear(): void {
    // console.log("登录页面加载")
    if (this.server.server == "") {
      return
    }
    let urlObj = url.URL.parseURL(this.server.server)
    this.serverHost = urlObj.hostname
    this.serverPort = urlObj.port
    this.username = this.server.username
    this.password = this.server.password
  }

  aboutToDisappear(): void {
    // console.log("登录页面销毁")
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          Text("请先安装服务端(同样是开源项目)再进行登录和备份，服务端地址：https://github.com/qicfan/backup-server")
            .width('100%')
            .padding($r('app.float.normal_padding'))
          IBestField({
            value: this.serverHost!!,
            label: "IP或域名",
            required: true,
            placeholder: "192.168.1.1",
          })
          IBestField({
            value: this.serverPort!!,
            label: "端口",
            required: true,
            placeholder: "5005",
          })
          IBestField({
            value: this.username!!,
            label: "用户名",
            required: true,
            placeholder: "请输入登录用户名",
          })
          IBestField({
            value: this.password!!,
            label: "密码",
            placeholder: "请输入登录密码",
            required: true,
            type: "password",
          })
          Column() {
            IBestButton({
              text: '添加',
              type: 'primary',
              loadingText: '验证是否可用...',
              loading: this.addBtnLoading,
              onBtnClick: () => {
                this.addServer()
              }
            })
          }
          .margin({ top: $r('app.float.normal_padding') })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .title("添加WebDav服务器")
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ibest_background'))
    .hideBackButton(this.pop)
    .onShown(() => {
      console.log('登录页面显示')
      this.pop = this.pageInfos.getParamByIndex(0) as boolean;
    })
  }
}