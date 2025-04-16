import { IBestButton, IBestNotify } from "@ibestservices/ibest-ui-v2";
import { ServerConfig } from "../models/Server";
import { AppStorageV2 } from "@kit.ArkUI";
import { abilityAccessCtrl, common, WantAgent, wantAgent } from "@kit.AbilityKit";
import { Global } from "../models/Global";
import { AccessStatus, ConfigGlobalStatus, LoginStatus, LowBatteryStop,
  OnlyWIFIBackup,
  TaskDoing, TaskStatus } from "../typing";
import { Config } from "../models/Config";
import { Settings } from "../components/Settings";
import { Login } from "../components/Login";
import { WebDav } from "../utils/webdav";
import { TaskList } from "../components/TaskList";
import { BusinessError, emitter } from "@kit.BasicServicesKit";
import { Task } from "../models/Task";
import { backgroundTaskManager } from "@kit.BackgroundTasksKit";
import { notificationManager } from "@kit.NotificationKit";
import { TaskItem } from "../models/TaskItem";
import { checkPermissionGrant } from "../utils/permission";
import { getBatteryLevel, getCurrentNetType } from "../utils/tool";
import { connection } from "@kit.NetworkKit";

@Entry
@ComponentV2
struct Index {
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => new ServerConfig())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => new Config())!;
  @Local webdav: WebDav = AppStorageV2.connect(WebDav, "webdav", () => new WebDav())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => new Global())!;
  private ctxUIAbility: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  @Provider('pageInfos') pageInfos: NavPathStack = new NavPathStack()
  @Local loading: boolean = false;
  private stop: boolean = false; // 是否停止执行
  private canProcess: boolean = true; // 是否能执行，比如WIFI，网络连接断开等
  private jobId: number = 0;

  aboutToAppear() {
    this.server.queryAsset().then((exists: boolean) => {
      if (!exists) {
        // 沒有添加服務器，彈出添加窗口
        return this.pageInfos.replacePath({ name: "login" })
      } else {
        this.global.loginStatus = LoginStatus.NO_LOGIN;
        // 检查服务器是否可用
        this.webdav.updateSerConfig(this.server);
        this.webdav.valid().then((rs) => {
          if (rs) {
            this.global.loginStatus = LoginStatus.LOGIN;
          } else {
            // 登录失败，重新登录
            return this.pageInfos.replacePath({ name: "login" })
          }
        })
      }
      this.config.init().then((exists: number) => {
        if (exists != 1) {
          return this.pageInfos.replacePath({ name: "Settings" })
        } else {
          this.global.configGlobalStatus = ConfigGlobalStatus.YES
        }
      }).catch(() => {
        return this.pageInfos.replacePath({ name: "Settings" })
      })
    }).catch(() => {
      return this.pageInfos.replacePath({ name: "login" })
    })
    // 等待触发新任务生成的事件
    emitter.on(Global.START_COLLECT_PHOTO_EVENT, () => {
      // 开始生成新任务
      console.log("准备生成新任务")
      IBestNotify.show({
        message: "正在扫描新照片并生成备份任务...",
        type: "warning",
        duration: 500000
      })
      Task.createTask(getContext(this)).then(() => {
        if (this.global.taskGlobalStatus == TaskDoing.YES) {
          IBestNotify.close();
          return ;
        }
        setTimeout(() => {
          this.global.taskGlobalStatus = TaskDoing.NO;
          IBestNotify.close();
          // 执行任务
          emitter.emit(Global.START_WAIT_TASK_EVENT);
        }, 1000)
      }).catch(() => {
        if (this.global.taskGlobalStatus == TaskDoing.YES) {
          IBestNotify.close();
          return ;
        }
        setTimeout(() => {
          this.global.taskGlobalStatus = TaskDoing.NO;
          IBestNotify.close();
          emitter.emit(Global.START_WAIT_TASK_EVENT);
        }, 1000)
      })
    })

    // 等待触发未完成任务继续执行的事件
    emitter.on(Global.START_WAIT_TASK_EVENT, () => {
      // 触发任务执行
      if (this.global.processId  > 0) {
        console.log("有正在执行的任务，本次不执行")
      } else {
        console.log("执行任务")
        this.process()
      }
    })
  }

  checkPerm(): Promise<boolean> {
    return new Promise((resolve) => {
      checkPermissionGrant('ohos.permission.READ_IMAGEVIDEO').then((s) => {
        if (s === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          // 已授权
          this.global.AccessStatus = AccessStatus.YES;
          resolve(true)
        } else {
          IBestNotify.show({
            message: "未授权访问相册，请到'设置 > 应用和元服务 > 相册备份'中打开'图片和视频 -> 仅读取'权限后再重新打开本应用",
            type: "warning",
            duration: 3000
          })
          this.global.AccessStatus = AccessStatus.NO;
          resolve(false)
        }
      })
    })

  }

  onPageShow(): void {
    console.log('index show')
    setTimeout(() => {
      this.checkPerm().then((p) => {
        if (!p) {
          return;
        }
        emitter.emit(Global.START_COLLECT_PHOTO_EVENT);
      })
    }, 3000)
  }

  checkBattery() {
    if (this.config.lowBatteryStop === LowBatteryStop.YES) {
      if (getBatteryLevel() <= 15) {
        this.canProcess = false;
        IBestNotify.show({
          message: "已打开低电量不备份，当前电量低于15%，不启动备份任务",
          type: "warning",
          duration: 3000
        })
        return false;
      }
    }
    return true;
  }

  async checkWifi() {
    if (this.config.onlyWifi === OnlyWIFIBackup.YES) {
      const netType = await getCurrentNetType();
      if (netType == connection.NetBearType.BEARER_CELLULAR) {
        this.canProcess = false;
        IBestNotify.show({
          message: "已打开仅wifi备份，当前使用移动网络，不启动备份任务",
          type: "warning",
          duration: 3000
        })
        return false;
      }
    }
    return true;
  }

  // 触发执行备份任务
  async process() {
    const p = this.checkPerm();
    if (!p) return ;
    if (this.jobId > 0) return ;
    this.checkBattery();
    this.checkWifi();
    if (!this.canProcess) return;
    if (this.config.backupRootPath === "") {
      IBestNotify.show({
        message: "请先设置备份路径",
        type: "warning",
        duration: 3000
      })
      return;
    }
    const task = await Task.getWaitList();
    if (task === undefined) {
      // 没有要执行的任务
      console.log("没有要执行的任务");
      return;
    }
    console.log("开始执行任务：" + task.id)
    this.global.taskGlobalStatus = TaskDoing.YES
    this.stop = false;
    this.startBackground(task)
  }

  // 停止任务
  stopTask(task:Task) {
    this.stop = true;
    this.global.processId = 0;
    task.finish();
  }

  startBackground(task: Task) {
    const webdav = new WebDav(this.server);
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      // 点击通知后，将要执行的动作列表
      wants: [{ bundleName: "com.xaxx.backup", abilityName: "EntryAbility" }],
      // 点击通知后，动作类型
      actionType: wantAgent.OperationType.START_ABILITY,
      // 使用者自定义的一个私有值
      requestCode: 0,
      // 点击通知后，动作执行属性
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    try {
      backgroundTaskManager.on("continuousTaskCancel", () => {
        // 标记任务状态，然后停止上传
        this.stopTask(task);
      });
      // 通过wantAgent模块下getWantAgent方法获取WantAgent对象
      wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
        try {
          let list: Array<string> = ["dataTransfer"];
          backgroundTaskManager.startBackgroundRunning(this.ctxUIAbility, list, wantAgentObj)
            .then(async (res: backgroundTaskManager.ContinuousTaskNotification) => {
              console.info("Operation startBackgroundRunning succeeded");
              emitter.emit(Global.START_TASK_EVENT, { data: { id: task.id } })
              // 对于上传下载类的长时任务，应用可以使用res中返回的notificationId来更新通知，比如发送带进度条的模板通知。
              this.jobId = res.notificationId;
              console.info("Operation startBackgroundRunning jobId: " + this.jobId);
              await task.start();
              console.log(`task ${task.id} started`)
              let page = 1;
              let pageSize = 100;
              console.log(`取第 ${page} 页数据`)
              while (true) {
                let curTotal = 0;
                const items: TaskItem[] = await task.getWaitItems(page, pageSize)
                for (let item of items) {
                  if (this.stop) {
                    // 停止执行
                    break
                  }
                  if (!this.checkBattery()) {
                    // 电量低于15%，停止
                    this.stop = true;
                    break;
                  }
                  if (!(await this.checkWifi())) {
                    // 非wifi网络，停止
                    this.stop = true;
                    break;
                  }
                  curTotal ++
                  task.preUploadedSize = task.uploadedSize;
                  item.updateWebDav(webdav, this.config)
                  try {
                    const rs = await item.upload(this.updateProcess)
                    if (rs) {
                      task.success++
                    } else {
                      task.failed ++;
                    }
                    await task.updateStat(task.success, task.failed);
                  } catch(e) {
                    task.failed ++;
                    await task.updateStat(task.success, task.failed);
                  } finally {
                    // 触发UI更新
                    emitter.emit(Global.START_TASK_EVENT, { data: { id: task.id } })
                    this.updateProcess(task)
                  }
                }
                if (curTotal >= pageSize && !this.stop) {
                  page ++;
                  continue;
                }
                await task.finish();
                // 触发UI更新
                this.global.taskGlobalStatus = TaskDoing.NO;
                this.jobId = 0;
                setTimeout(() => {
                  emitter.emit(Global.START_TASK_EVENT, { data: { id: task.id } })
                }, 1000)
                // 取消长时任务
                backgroundTaskManager.stopBackgroundRunning(this.ctxUIAbility);
                // 触发下一次执行
                emitter.emit(Global.START_WAIT_TASK_EVENT)
                break;
              }
            })
            .catch((error: BusinessError) => {
              console.error(`Operation startBackgroundRunning failed. code is ${error.code} message is ${error.message}`);
            });
        } catch (error) {
          console.error(`Operation startBackgroundRunning failed. code is ${(error as BusinessError).code} message is ${(error as BusinessError).message}`);
        }
      });
    } catch (error) {
      console.error(`Operation getWantAgent failed. code is ${(error as BusinessError).code} message is ${(error as BusinessError).message}`);
    }
  }

  // 应用更新进度
  updateProcess(task: Task) {
    // 应用定义下载类通知模版
    const cur = task.success + task.failed
    const process: number = Math.floor(task.uploadedSize / task.size * 100);

    let downLoadTemplate: notificationManager.NotificationTemplate = {
      name: 'downloadTemplate', // 当前只支持downloadTemplate，保持不变
      data: {
        title: `正在备份照片`, // 必填。
        fileName: `进度：${cur}/${task.total}`, // 必填。
        progressValue: process, // 应用更新进度值，自定义。
      }
    };
    let request: notificationManager.NotificationRequest = {
      content: {
        // 系统实况类型，保持不变
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
        systemLiveView: {
          typeCode: 8, // 上传下载类型需要填写 8，当前仅支持此类型。保持不变
          title: "正在备份照片", // 应用自定义
          text: `进度：${cur}/${task.total}`, // 应用自定义
        }
      },
      id: this.jobId, // 必须是申请长时任务返回的id，否则应用更新通知失败。
      notificationSlotType: notificationManager.SlotType.LIVE_VIEW, // 实况窗类型，保持不变
      template: downLoadTemplate // 应用需要设置的模版名称
    };

    try {
      notificationManager.publish(request).then(() => {
        console.info("publish success, id= " + this.jobId);
      }).catch((err: BusinessError) => {
        console.error(`publish fail: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`publish fail: ${JSON.stringify(err)}`);
    }
  }

  @Builder
  PageMap(name: string) {
    if (name === "login") {
      Login()
    }
    if (name === "Settings") {
      Settings()
    }
  }

  build() {
    Navigation(this.pageInfos) {
      Column() {
        TaskList()
          .width('100%')
          .layoutWeight(1)
        Column() {
          IBestButton({
            text: '开始备份',
            type: (this.global.taskGlobalStatus == TaskDoing.YES) ? 'default' : 'primary',
            loadingText: "操作中...",
            loading: this.global.taskGlobalStatus == TaskDoing.YES
          })
            .onClick(() => {
              this.global.taskGlobalStatus = TaskDoing.YES;
              emitter.emit(Global.START_COLLECT_PHOTO_EVENT);
            })
        }
        .width('100%')
        .margin({ bottom: $r("app.float.normal_padding") })
      }
    }
    .title("相册备份")
    .navDestination(this.PageMap)
    .mode(NavigationMode.Stack)
    .menus([
      {
        value: "设置", icon: $r("app.media.gearshape"), action: () => {
        this.pageInfos.pushPath({ name: "Settings" })
      }
      }
    ])
    .backgroundColor($r('app.color.ibest_background'))
    .width('100%')
    .height('100%')
  }
}