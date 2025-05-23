import { CommonConstants } from "../common/CommonConstants";
import { TaskItem } from "../models/TaskItem"
import { TaskBottom } from "./TaskBottom";
import { TaskItemComponent } from "./TaskItemComponent";
import { IBestEmpty } from "@ibestservices/ibest-ui-v2";
import { TaskCheck } from "./TaskCheck";
import { WaitTaskItemDataSource } from "../models/TaskItemDataSource";
import { WinBreakpoint } from "../common/WinBreakpoint";
import { AppStorageV2 } from "@kit.ArkUI";
import { emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";
import { TaskDoing } from "../typing";
import { BreakpointConstants } from "../common/BreakpointConstants";

@ComponentV2
export struct WaitList {
  @Local isRefreshing: boolean = false;
  @Local isLoading: boolean = false;
  @Local total: number = 0;
  @Local winBP: WinBreakpoint =
    AppStorageV2.connect(WinBreakpoint, 'windowBreakpoint', () => WinBreakpoint.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Provider("taskItemDataSource") data: WaitTaskItemDataSource = new WaitTaskItemDataSource();

  private scroller: Scroller = new Scroller();
  page: number = 1;
  @Local pageSize: number = 100;
  aboutToAppear(): void {
    this.getList(1).then(() => {})
    emitter.on(Global.COLLECT_PHOTO_FINISH_EVENT, (data) => {
      if (data.data?.exists === true) {
        // 如果有新项目则刷新页面
        this.getList(1).then(() => {})
      }
    })
    emitter.on(Global.BACKUP_TASK_FINISH, () => {
      // 备份完成后刷新页面
      this.getList(1).then(() => {})
    })
  }

  async getList(page: number = 1) {
    this.pageSize = this.winBP.imagePageSize;
    if (page === 1) {
      this.total = TaskItem.getWaitCount();
    }
    this.page = page;
    // 查询未备份照片列表
    const items = await TaskItem.getWaitList(page, this.pageSize)
    if (this.page === 1) {
      this.data.clearData();
    }
    this.data.addData(items);
    if (this.page === 1) {
      this.data.notifyDataReload();
    }
  }

  get hasMore(): boolean {
    if (this.data.totalCount() >= this.total) return false;
    return true;
  }

  onRefresh(direction: string) {
    if (this.global.processId > 0) {
      this.isRefreshing = false;
      return ;
    }
    if (direction === 'pull') {
      this.getList(1).then(() => {
        console.log(`hasMore: ${this.hasMore}`)
        console.log('onRefreshing pull');
        this.isRefreshing = false;
      })
    } else {
      // 上滑加载更多
      console.log(`加载更多,页数:${this.page + 1}, pageSize: ${this.winBP.imagePageSize}`)
      this.getList(this.page + 1).then(() => {
        console.log(`hasMore: ${this.hasMore}`)
        console.log('onRefreshing slide');
        this.isRefreshing = false;
      })
    }
  }

  build() {
    Column() {
      if (this.winBP.currentWidthBreakpoint !== BreakpointConstants.BREAKPOINT_SM ||
        this.winBP.currentHeightBreakpoint !== BreakpointConstants.BREAKPOINT_MD) {
        Refresh({ refreshing: $$this.isRefreshing, promptText: "下拉刷新待备份列表" }) {
          if (this.total > 0) {
            Grid(this.scroller) {
              LazyForEach(this.data, (item: TaskItem, index: number) => {
                GridItem() {
                  TaskItemComponent({ taskItem: item, index: index })
                }
              }, (item: TaskItem) => item ? item.id + '' : "0")
            }
            .margin($r('app.float.normal_padding'))
            .cachedCount(this.pageSize * 2)
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
              console.log(`scroll index start=${start}, end=${end}`)
              if (!this.hasMore) return;
              if (end < this.data.totalCount() - 1) return;
              this.isLoading = true;
              this.getList(this.page + 1).then(() => {
                this.isLoading = false;
              })
            })
          } else {
            IBestEmpty({
              description: "没有需要备份的照片或视频"
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .onRefreshing(() => {
          this.onRefresh('pull')
        })
      }
      if (this.total > 0 && this.global.taskGlobalStatus === TaskDoing.NO) {
        TaskBottom()
          .width('100%')
      } else {
        TaskCheck()
          .width('100%')
      }
    }
    .width(CommonConstants.FULL_PERCENT)
    .height(CommonConstants.FULL_PERCENT)
    .justifyContent(FlexAlign.Start)
  }
}