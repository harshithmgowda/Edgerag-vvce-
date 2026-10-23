from pathlib import Path
import shutil
r=Path.cwd(); source=Path('C:/Users/Harshith/AppData/Local/Pub/Cache/hosted/pub.dev/fllama-0.0.1'); target=r/'packages/fllama'
shutil.copytree(source,target,ignore=shutil.ignore_patterns('example','.dart_tool','build'),dirs_exist_ok=True)
p=target/'android/build.gradle';s=p.read_text().replace("proguard-android.txt","proguard-android-optimize.txt");p.write_text(s)
(target/'EDGERAG_PATCH.md').write_text('Vendored from pub.dev fllama 0.0.1 (MIT; see LICENSE). Android Gradle configuration uses proguard-android-optimize.txt for AGP 9 compatibility. Native sources are unchanged. No model weights are included.\n')
p=r/'apps/mobile/pubspec.yaml';s=p.read_text().replace('fllama: 0.0.1','fllama:\n    path: ../../packages/fllama').replace('fllama: ^0.0.1','fllama:\n    path: ../../packages/fllama');p.write_text(s)
