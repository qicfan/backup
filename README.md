## 鸿蒙5.0 鸿蒙Next(HarmonyOS Next) 相册备份
### 使用websocket协议备份图库到NAS，从NAS下载照片到本地，支持动态照片

#### 测试版本链接：[https://appgallery.huawei.com/link/invite-test-wap?taskId=cd1d1a840df25d887bc6676cea7b8308](https://appgallery.huawei.com/link/invite-test-wap?taskId=6ba7bd8c12fe21f814cff6c8330f4010)
#### 基于5.0.4(API 16)，请确保您设备的系统版本大于等于该版本
#### 本项目为客户端，需要部署服务端才能使用：[https://github.com/qicfan/backup-server](https://github.com/qicfan/backup-server)
#### 备份的照片暂时没有exif，这是鸿蒙系统的限制，所以备份完成后不要删除源文件，后续支持exif后可以重新备份
### TODO LIST
- [x] 使用关键资产存储服务器、用户名、密码
- [x] 使用关系型数据库存储数据
- [x] 使用websocket协议传输文件，并发5个线程
- [x] 使用长时任务执行备份
- [x] 低电量停止备份
- [x] 仅wifi备份
- [x] 任务手动启停
- [x] 将备份服务器的照片保存到本地相册
- [x] 支持将apple的动态照片转码成jpg+mp4保存到鸿蒙相册
