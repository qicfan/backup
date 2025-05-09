import { hilog } from '@kit.PerformanceAnalysisKit';
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { FormData } from '../common/CommonData';

const TAG: string = 'EntryFormAbility';
const DOMAIN_NUMBER: number = 0xFF00;

export default class EntryBackupAbility extends FormExtensionAbility  {
  onAddForm(want: Want): formBindingData.FormBindingData {
    if(!want || !want.parameters) {
      hilog.error(0x0000, TAG, `FormAbility onAddForm want or want.parameters is undefined`);
      return formBindingData.createFormBindingData('');
    }

    let formName: string = want.parameters[formInfo.FormParam.NAME_KEY] as string;
    let formId: string = want.parameters[formInfo.FormParam.IDENTITY_KEY] as string;
    let storage: LocalStorage = new LocalStorage();
    storage.setOrCreate('formId', formId);
    let formData = new FormData(formId);
    return formBindingData.createFormBindingData(formData);
  }

  onCastToNormalForm(formId: string): void {
    // 卡片使用方将临时卡片转换为常态卡片触发，提供方需要做相应的处理。
    // 1、临时卡、常态卡是卡片使用方的概念。
    // 2、临时卡是短期存在的，在特定事件或用户行为后显示，完成后自动消失。
    // 3、常态卡是持久存在的，在用户未进行清除或更改的情况下，会一直存在，平时开发的功能卡片属于常态卡。
    // 4、目前手机上没有地方会使用临时卡。
    hilog.info(DOMAIN_NUMBER, TAG, '[EntryFormAbility] onCastToNormalForm');
  }

  onUpdateForm(formId: string): void {
    // 若卡片支持定时更新/定点更新/卡片使用方主动请求更新功能，则提供方需要重写该方法以支持数据更新
    hilog.info(DOMAIN_NUMBER, TAG, '[EntryFormAbility] onUpdateForm');
    let obj: Record<string, string> = {
      'title': 'titleOnUpdateForm',
      'detail': 'detailOnUpdateForm'
    };
    let formData: formBindingData.FormBindingData = formBindingData.createFormBindingData(obj);
    formProvider.updateForm(formId, formData).catch((error: BusinessError) => {
      hilog.info(DOMAIN_NUMBER, TAG, '[EntryFormAbility] updateForm, error:' + JSON.stringify(error));
    });
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    // 卡片使用方发起可见或者不可见通知触发，提供方需要做相应的处理，仅系统应用生效
    hilog.info(DOMAIN_NUMBER, TAG, '[EntryFormAbility] onChangeFormVisibility');
  }

  onFormEvent(formId: string, message: string): void {
    // 若卡片支持触发事件，则需要重写该方法并实现对事件的触发
    hilog.info(DOMAIN_NUMBER, TAG, '[EntryFormAbility] onFormEvent');
    // ...
  }

  onRemoveForm(formId: string): void {
    // 删除卡片实例数据
    hilog.info(DOMAIN_NUMBER, TAG, '[EntryFormAbility] onRemoveForm');
    // 删除之前持久化的卡片实例数据
    // 此接口请根据实际情况实现，具体请参考：FormExtAbility Stage模型卡片实例
  }

  onAcquireFormState(want: Want) {
    // 卡片提供方接收查询卡片状态通知接口，默认返回卡片初始状态。
    return formInfo.FormState.READY;
  }
}