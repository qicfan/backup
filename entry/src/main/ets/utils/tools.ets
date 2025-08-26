import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { connection } from '@kit.NetworkKit';
import { batteryInfo, BusinessError } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { LowBatteryStop, OnlyWIFIBackup } from '../typing';
import { IBestNotify } from '@ibestservices/ibest-ui-v2';
import { Config } from '../models/Config';

/**
 * Copy the source image into sandbox.
 * @param src - source image path
 * @param path - sandbox path
 * @returns Promise<string>
 */
export function copyImg2Sandbox(src: string, path: string, size: number): boolean {
  // 检查文件是否存在，大小是否一致
  let srcImage: fileIo.File;
  let destImage: fileIo.File;
  try {
    srcImage = fileIo.openSync(src, fileIo.OpenMode.READ_ONLY);
  } catch (e) {
    console.error(`复制文件: ${src}=>${path}失败，code: ${e.code}, msg: ${e.message}`);
    return false;
  }
  try {
    destImage = fileIo.openSync(path, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE);
  } catch (e) {
    console.error(`复制文件: ${src}=>${path}失败，code: ${e.code}, msg: ${e.message}`);
    return false;
  }
  let exists: boolean = false;
  try {
    fileIo.statSync(destImage.fd);
    exists = true;
  } catch (e) {
    console.log(`获取目标文件${path}的状态出错：code:${e.code}, msg:${e.message}}`)
    exists = false;
  }
  if (exists) {
    return true
  }
  try {
    // const chunkSize = 1024; // 1KB
    // let buffer = new ArrayBuffer(chunkSize);
    // let readResult: number;
    // do {
    //   readResult = fileIo.readSync(srcImage.fd, buffer);
    //   if (readResult > 0) {
    //     // 创建适当大小的缓冲区
    //     const writeBuffer = readResult < chunkSize ? buffer.slice(0, readResult) : buffer;
    //     fileIo.writeSync(destImage.fd, writeBuffer);
    //   }
    // } while (readResult > 0);
    fileIo.copyFileSync(srcImage.fd, destImage.fd)
    console.info(`复制文件: ${src}=>${path}成功`);
  } catch (e) {
    console.error(`复制文件: ${src}=>${path}失败，code: ${e.code}, msg: ${e.message}`);
    return false
  } finally {
    fileIo.closeSync(srcImage);
    fileIo.closeSync(destImage);
  }
  let d: fileIo.File
  try {
    d = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    let destStat = fileIo.statSync(d.fd)
    console.log(`复制完成的文件${path}，文件大小：${destStat.size}`)
  } catch (e) {
    console.error(`检查复制完成的文件大小: ${path}, message=${e.message}, code=${e.code}`)
    return false
  } finally {
    fileIo.closeSync(d!);
  }
  return true;
}

export function deleteFile(filePath: string) {
  try {
    fileIo.unlinkSync(filePath)
    console.info(`删除文件成功：${filePath}`)
  } catch (e) {
    console.error(`删除文件错误，code:${e.code}, 错误信息：${e.message}`)
  }
  return;
}

export function splitFileExt(filePath: string): string[] {
  const l: string[] = filePath.split('.');
  let ext: string | undefined = l.pop();
  if (!ext) {
    ext = '';
  }
  const name = l.join('.')
  return [ext, name]
}

export function getMimeTypeFromExtension(filePath: string): string {
  const extension = filePath.split('.').pop()?.toLowerCase() ?? '';

  const mimeMap: Record<string, string> = {
    'txt': 'text/plain',
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'mp3': 'audio/mpeg',
    'mp4': 'video/mp4',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip': 'application/zip',
    'rar': 'application/x-rar-compressed',
    'json': 'application/json',
    'html': 'text/html',
    'css': 'text/css',
    'js': 'text/javascript'
  };

  return mimeMap[extension] || 'application/octet-stream';
}

export function fileName(filePath: string): string {
  const l = filePath.split('/')
  const name = l.pop()
  if (!name) return filePath;
  return name;
}

export function base64Encode(str: string) {
  const base64 = new util.Base64Helper();
  const encoder = new util.TextEncoder()
  return base64.encodeToStringSync(encoder.encodeInto(str));
}

/**
 * 获取当前网络类型
 * @returns 返回网络类型字符串
 */
export async function getCurrentNetType(): Promise<connection.NetBearType> {
  try {
    const netHandle = await connection.getDefaultNet();
    const netCapabilities = await connection.getNetCapabilities(netHandle);
    return netCapabilities.bearerTypes[0];
  } catch (error) {
    console.error('获取网络类型失败:', (error as BusinessError).message);
    return connection.NetBearType.BEARER_WIFI;
  }
}

/**
 * 获取当前电池电量百分比
 * @returns 电量百分比(0-100)
 */
export function getBatteryLevel(): number {
  try {
    const batteryLevel = batteryInfo.batterySOC;
    // console.log(`当前电量: ${batteryLevel}%`);
    return batteryLevel;
  } catch (error) {
    console.error('获取电量失败:', (error as BusinessError).message);
    return -1; // 返回-1表示获取失败
  }
}

export function formatFileSize(size: number): string {
  if (size < 1024 * 1024) {
    // KB
    return (size / 1024).toFixed(2) + 'KB'
  }
  if (size >= 1024 * 1024 && size < 1024 * 1024 * 1024) {
    // MB
    return (size / 1024 / 1024).toFixed(2) + 'MB'
  }
  if (size >= 1024 * 1024 * 1024 && size < 1024 * 1024 * 1024 * 1024) {
    // GB
    return (size / 1024 / 1024 / 1024).toFixed(2) + 'GB'
  }
  // PB
  return (size / 1024 / 1024 / 1024 / 1024).toFixed(2) + 'PB'
}

export function fileSize(filePath: string): number {
  try {
    const stat = fileIo.statSync(filePath)
    return stat.size;
  } catch (e) {
    return -1;
  }

}

// 计算文件hash
export async function calculateFileHash(fileStream: fileIo.Stream, size: number): Promise<string> {
  try {
    const sha256 = cryptoFramework.createMd('MD5');
    const bufferSize = 4096;
    let offset = 0;

    while (offset < size) {
      const readSize = Math.min(bufferSize, size - offset);
      const arrayBuffer = new ArrayBuffer(readSize);
      // await fileIo.read(file.fd, arrayBuffer, { offset });
      await fileStream.read(arrayBuffer, {offset: offset, length: readSize})
      await sha256.update({ data: new Uint8Array(arrayBuffer) });
      offset += readSize;
    }
    const hash = await sha256.digest();
    // const textDecoder: util.TextDecoder = util.TextDecoder.create(); // 调用util模块的TextDecoder类
    // const result: string = textDecoder.decodeToString(hash.data); // 对uint8Array解码
    return Array.from(hash.data)
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
  } catch (error) {
    console.error('计算文件哈希出错:', (error as BusinessError).message);
    return "";
  }
}

export function strip(str: string, trip: string) {
  return str.endsWith(trip) ? str.slice(0, -1) : str;
}
export function ltrip(str: string, trip: string) {
  return str.startsWith(trip) ? str.substring(1) : str
}

export function checkBattery(config: Config) {
  if (config.lowBatteryStop === LowBatteryStop.YES) {
    if (getBatteryLevel() <= 15) {
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

export async function checkWifi(config: Config) {
  if (config.onlyWifi === OnlyWIFIBackup.YES) {
    const netType = await getCurrentNetType();
    if (netType == connection.NetBearType.BEARER_CELLULAR) {
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