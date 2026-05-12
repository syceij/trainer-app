import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';
import './index.css';

import { Capacitor } from '@capacitor/core';
import { StatusBar, Style } from '@capacitor/status-bar';
import { Keyboard } from '@capacitor/keyboard';
import { App as CapApp } from '@capacitor/app';

if (Capacitor.isNativePlatform()) {
  // Status bar — dark icons on black background.
  // Capacitor's contentInset:"always" already extends the WebView under the
  // status bar; calling setOverlaysWebView here conflicts with that and
  // breaks the layout height, so we leave it as the default.
  StatusBar.setStyle({ style: Style.Dark });
  StatusBar.setBackgroundColor({ color: '#000000' });

  // Android back button
  CapApp.addListener('backButton', ({ canGoBack }) => {
    if (canGoBack) {
      window.history.back();
    } else {
      CapApp.exitApp();
    }
  });

  // Keyboard — push content up on iOS
  Keyboard.addListener('keyboardWillShow', info => {
    document.body.style.paddingBottom = `${info.keyboardHeight}px`;
  });

  Keyboard.addListener('keyboardWillHide', () => {
    document.body.style.paddingBottom = '0px';
  });
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
