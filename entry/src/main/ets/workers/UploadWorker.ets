import { MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { UploadEvent } from '../typing';
import { fileIo } from '@kit.CoreFileKit';
import { webSocket } from '@kit.NetworkKit';
import { ApiResponse, PathItem } from '../utils/server';
import { BusinessError } from '@kit.BasicServicesKit';
import { sha256 } from '../utils/tools';

interface FileChunk {
  fileName: string
  type: number
  live_photo_video_path: string
  mtime: number
  ctime: number
  fileUri: string
  size: number
  chunkIndex: number
  chunkCount: number
  chunkHash: string
}
const workerPort: ThreadWorkerGlobalScope = worker.workerPort;
const CHUNK_SIZE = 100 * 1024 // 100kb
let SI: number = 0
let LAST_SIZE: number = 0
let CURRENT_SIZE: number = 0
let PROGRESS = 0
let ws: webSocket.WebSocket | undefined = undefined
workerPort.onmessage = async (event: MessageEvents) => {
  // console.log(`上传线程收到消息：${JSON.stringify(event.data)}`)
  // 要上传的对象
  let data: UploadEvent = event.data as UploadEvent
  LAST_SIZE = 0
  CURRENT_SIZE = 0
  PROGRESS = 0
  doUpload(data)
};

async function doUpload(uploadFile: UploadEvent) {
  // console.log(`开始上传: ${uploadFile.fileUri}`)
  let file: fileIo.File
  try {
    file = fileIo.openSync(uploadFile.fileUri, fileIo.OpenMode.READ_ONLY)
  } catch (e) {
    console.error(`文件 ${uploadFile.fileUri} 打开失败，Code ${e.code}, 错误 ${e.message}`)
    return
  }
  let stat: fileIo.Stat
  try {
    stat = fileIo.statSync(file.fd);
  } catch (e) {
    console.error(`文件 ${uploadFile.fileUri} 获取信息失败，Code ${e.code}, 错误 ${e.message}`)
    return
  }
  // console.log(`文件 ${uploadFile.path}打开成功，文件大小 ${stat.size}`)
  let fileSize = stat.size;
  let chunkCount = Math.ceil(fileSize / CHUNK_SIZE);
  // console.log(`${uploadFile.path} 文件大小 ${fileSize}，分片数量: ${chunkCount}`)
  let wsObj = await connectWs(uploadFile)
  // 启动定时器测速
  SI = setInterval(() => {
    if (CURRENT_SIZE === 0 && LAST_SIZE === 0) {
      return
    }
    let size = (CURRENT_SIZE - LAST_SIZE) * 2 // 速度，字节
    // console.log(`文件 ${uploadFile.fileUri} 当前进度：${CURRENT_SIZE}, ${LAST_SIZE}/${fileSize}, 速度: ${size}`)
    PROGRESS = Math.floor(CURRENT_SIZE / fileSize * 100)
    let rs: ApiResponse<number[]> = {code: 2, message: "", data: [size, CURRENT_SIZE, PROGRESS]}
    workerPort.postMessage(rs)
    LAST_SIZE = CURRENT_SIZE
  }, 500)
  for (let i = 0; i < chunkCount; i++) {
    // console.log(`开始上传分片: ${uploadFile.path} => ${i}`)
    let start = i * CHUNK_SIZE;
    let end = Math.min(start + CHUNK_SIZE, fileSize);
    // console.log(`分片 ${i} Start ${start}, End ${end}`)
    let buffer = new ArrayBuffer(end - start);
    try {
      fileIo.readSync(file.fd, buffer, { offset: start, length: end - start });
    } catch (e) {
      console.error(`分片 ${i} 读取内容失败, Code ${e.code}, 错误：${e.message}`)
      clearInterval(SI)
      fileIo.closeSync(file.fd)
      return
    }
    // console.log(`分片 ${i} 读取文件完成`)
    let chunk: FileChunk = {
      fileName: uploadFile.path,
      type: 1, // 普通照片，按需调整
      live_photo_video_path: uploadFile.live_photo_video_path,
      mtime: Math.floor(stat.mtime / 1000),
      ctime: Math.floor(stat.ctime / 1000),
      fileUri: '',
      size: fileSize,
      chunkIndex: i,
      chunkCount: chunkCount,
      chunkHash: await sha256(buffer),
    };
    // console.log(`分片 ${i} 数据: ${JSON.stringify(chunk)}`)

    await wsObj.send(JSON.stringify(chunk)); // 先发JSON帧
    // console.log(`发送分片 ${i} 的数据帧，数据长度：${buffer.byteLength}`)
    await wsObj.send(buffer); // 再发二进制分片数据
    CURRENT_SIZE = end
  }
  let rs: ApiResponse<number[]> = {code: 2, message: "", data: [0, fileSize, 100]}
  workerPort.postMessage(rs)
  if (SI > 0) {
    clearInterval(SI)
    SI = 0
  }
  fileIo.closeSync(file.fd);

}

async function connectWs(uploadFile: UploadEvent): Promise<webSocket.WebSocket> {
  return new Promise((resolve, reject) => {
    if (ws !== undefined) {
      resolve(ws)
      return
    }
    let wsTmp = webSocket.createWebSocket();
    let server: string = ""
    if (uploadFile.server.indexOf('http://') >= 0) {
      server = uploadFile.server.replace('http://', 'ws://')
    } else if (uploadFile.server.indexOf('https://') >= 0) {
      server = uploadFile.server.replace('https', 'wss')
    }
    wsTmp.connect(`${server}/upload`, { header: {"Sec-WebSocket-Protocol": uploadFile.token}}).then((connected: boolean) => {
      if (!connected) {
        let rs: ApiResponse<undefined> = {code: 1, message: "ws服务链接失败", data: undefined}
        workerPort.postMessage(rs)
        return
      }
    })
    wsTmp.on('open', async () => {
      ws = wsTmp
      // console.log(`ws 连接成功：${server}`)
      resolve(ws)
    });
    wsTmp.on('message', (err: BusinessError<void>, data: string | ArrayBuffer) => {
      try {
        // console.log('ws message: ' + data as string)
        let resp = JSON.parse(data as string) as ApiResponse<PathItem>;
        if (resp.code === 0 && resp.message === '上传完成') {
          console.log('上传完成:', uploadFile.path, resp.data);
          // 通知主线程
          workerPort.postMessage(resp)
        } else if (resp.code === 1) {
          console.error('分片校验失败:', resp.message, resp.data);
          workerPort.postMessage(resp)
        }
      } catch (e) {
        // console.log('收到消息:', data as string);
      }
    });
    wsTmp.on('error', (err) => {
      console.error('WebSocket error:', JSON.stringify(err));
      reject(err)
    });
    return
  })

}