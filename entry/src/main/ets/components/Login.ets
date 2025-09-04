import { ServerConfig } from "../models/Server";
import { AppStorageV2 } from "@kit.ArkUI";
import { IBestButton, IBestCell, IBestField, IBestNotify, IBestSwitch } from "@ibestservices/ibest-ui-v2";
import { BusinessError } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";
import { LoginStatus } from "../typing";
import { url } from "@kit.ArkTS";
import { BackupServer } from "../utils/server";
import { Config } from "../models/Config";

@ComponentV2
export struct Login {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack()
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  @Local backupServer: BackupServer = AppStorageV2.connect(BackupServer, "BackupServer", () => BackupServer.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local addBtnLoading: boolean = false;
  @Local isHttps: boolean = false
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
    let protocol = 'http'
    if (this.isHttps) {
      protocol = 'https'
    }
    let host = this.serverHost.replace(/^\//, '');
    let port = this.serverPort.replace(/^\//, '');
    let server = `${protocol}://${host}:${port}`;
    let isRestBackupRootPath = false
    if (this.server.server !== server) {
      // 如果更改了服务器地址，责清空bakcupRootPath
      isRestBackupRootPath = true
    }
    this.server.server = server
    this.server.username = this.username;
    this.server.password = this.password;
    this.backupServer.updateConfig(this.server)
    const rs = await this.backupServer.login();
    if (!rs.success) {
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
      if (isRestBackupRootPath) {
        this.config.backupRootPath = ""
        await this.config.update()
      }
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
    let protocol = urlObj.protocol
    this.isHttps = false
    if (protocol == 'https') {
      this.isHttps = true
    }
    this.serverHost = urlObj.hostname
    this.serverPort = urlObj.port
    this.username = this.server.username
    this.password = this.server.password
  }

  aboutToDisappear(): void {
    // console.log("登录页面销毁")
  }

  @Builder httpsSwitch() {
    IBestSwitch({
      value: this.isHttps!!
    })
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
          IBestCell({
            title: '是否启用HTTPS',
            center: true,
            required: true,
            hasBorder: true,
            valueBuilder: () => this.httpsSwitch()
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