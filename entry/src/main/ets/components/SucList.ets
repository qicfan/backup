import { CommonConstants } from "../common/CommonConstants";
import { IBestButton, IBestEmpty, IBestNotify } from "@ibestservices/ibest-ui-v2";
import { SucTaskItemDataSource } from "../models/TaskItemDataSource";
import { WinBreakpoint } from "../common/WinBreakpoint";
import { AppStorageV2 } from "@kit.ArkUI";
import { Global } from "../models/Global";
import { BackupServer, ServerPhotoItem } from "../utils/server";
import { ServerPhotoItemComponent } from "./ServerPhotoItemComponent";
import { ServerConfig } from "../models/Server";
import { Config } from "../models/Config";
import { ConfigGlobalStatus, LoginStatus } from "../typing";

@ComponentV2
export struct SucList {
  @Local isRefreshing: boolean = false;
  @Local isLoading: boolean = false;
  @Local winBP: WinBreakpoint =
    AppStorageV2.connect(WinBreakpoint, 'windowBreakpoint', () => WinBreakpoint.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local backupServer: BackupServer = AppStorageV2.connect(BackupServer, "BackupServer", () => BackupServer.getInstance())!;
  @Provider("taskItemDataSource") data: SucTaskItemDataSource = new SucTaskItemDataSource();
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @Local total: number = 0
  private scroller: Scroller = new Scroller();
  page: number = 1;
  pageSize: number = 50;
  aboutToAppear(): void {
    if (this.server.server !=="" && this.config.backupRootPath !== "") {
      this.getList(1).then(() => {
      })
    }
  }

  async getList(page: number = 1) {
    this.page = page
    console.log('刷新列表：page=' + page)
    this.isLoading = true
    let resp = await this.backupServer.photoList(page, this.pageSize)
    this.isLoading = false
    if (!resp || !resp.success || !resp.result) {
      console.warn(`查询照片列表失败，错误：${resp?.message}`)
      IBestNotify.show({
        message: resp.message,
        duration: 3000,
        type: 'warning'
      });
      return
    }
    this.total = resp.result.data.total
    // this.data.setTotalCount(resp.result.data.total)
    if (this.page === 1) {
      this.data.clearData();
      console.log('已清空列表')
    }
    this.data.addData(resp.result.data.photos);
    if (this.page === 1) {
      this.data.notifyDataReload();
    }
  }

  get hasMore(): boolean {
    console.log(`hasMore: ${this.total} ${(this.page-1) * this.pageSize}`)
    if (this.total <= (this.page - 1) * this.pageSize) return false;
    return true;
  }

  onRefresh(direction: string) {
    if (direction === 'pull') {
      this.getList(1).then(() => {
        this.isRefreshing = false;
      })
    } else {
      // 上滑加载更多
      this.getList(this.page + 1).then(() => {
        this.isRefreshing = false;
      })
    }
  }

  @Builder Btn() {
    IBestButton({ text: '添加服务器', type: 'primary', onBtnClick: () => {
      this.pageInfos.pushPath({ name: "login" })
    } })
      .padding({top: $r("app.float.normal_padding")})
  }

  build() {
    Column() {
      if (this.global.loginStatus == LoginStatus.LOGIN && this.global.configGlobalStatus == ConfigGlobalStatus.YES) {
        Refresh({ refreshing: $$this.isRefreshing, promptText: "下拉刷新" }) {
          if (this.total > 0) {
            Grid(this.scroller) {
              LazyForEach(this.data, (item: ServerPhotoItem, index: number) => {
                GridItem() {
                  ServerPhotoItemComponent({ serverPhotoItem: item, index: index })
                }
              }, (item: ServerPhotoItem) => item.path)
            }
            .margin($r('app.float.normal_padding'))
            .cachedCount(10)
            .rowsGap(3)
            .columnsGap(3)
            .columnsTemplate(`repeat(auto-fit, ${this.winBP.imageSize})`)
            .nestedScroll({
              scrollForward: NestedScrollMode.PARENT_FIRST,
              scrollBackward: NestedScrollMode.SELF_FIRST,
            })
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .scrollBar(BarState.Auto)
            .onScrollIndex((start: number, end: number) => {
              if (!this.hasMore) return;
              if (end < this.data.totalCount() - 1) return;
              this.isLoading = true;
              this.getList(this.page + 1).then(() => {
                this.isLoading = false;
              })
            })
          } else {
            IBestEmpty({
              description: "还没有已备份的照片或视频"
            })
          }
        }
        .width('100%')
        .height('100%')
        .onRefreshing(() => {
          this.onRefresh('pull')
        })
      } else {
        // 显示去登录的按钮
        IBestEmpty({
          description: '添加服务器后显示服务器中已备份的照片和视频',
          defaultBuilder: (): void => this.Btn()
        })
      }
    }
    .width(CommonConstants.FULL_PERCENT)
    .height(CommonConstants.FULL_PERCENT)
    .justifyContent(FlexAlign.Start)
  }
}