import { Haptics, ImpactStyle, NotificationType } from '@capacitor/haptics';
import { Capacitor } from '@capacitor/core';

export const hapticLight = async () => {
  if (Capacitor.isNativePlatform()) {
    await Haptics.impact({ style: ImpactStyle.Light });
  }
};

export const hapticMedium = async () => {
  if (Capacitor.isNativePlatform()) {
    await Haptics.impact({ style: ImpactStyle.Medium });
  }
};

export const hapticHeavy = async () => {
  if (Capacitor.isNativePlatform()) {
    await Haptics.impact({ style: ImpactStyle.Heavy });
  }
};

export const hapticSuccess = async () => {
  if (Capacitor.isNativePlatform()) {
    await Haptics.notification({ type: NotificationType.Success });
  }
};
