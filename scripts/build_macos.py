import argparse
import os
import platform
import re
import shlex
import shutil
import subprocess
import zipfile
from pathlib import Path

from app_build import BuildVariant, add_variant_argument

root = Path(__file__).resolve().parents[1]
deployment_target = '12.0'


def run(arguments, **kwargs):
    subprocess.run(arguments, cwd=kwargs.pop('cwd', root), check=True, **kwargs)


def build_core(variant=BuildVariant()):
    if platform.system() != 'Darwin':
        raise SystemExit('macOS 构建需要 macOS 和完整 Xcode。')
    go = shutil.which('go')
    if not go:
        raise SystemExit('请安装 Go 1.24.1 或更新版本。')
    environment = os.environ.copy()
    environment.setdefault('GOPROXY', 'https://goproxy.cn,direct')
    environment.setdefault('GOSUMDB', 'off')
    environment['CGO_ENABLED'] = '1'
    environment['GOTOOLCHAIN'] = os.environ.get('GOTOOLCHAIN', 'auto')
    sdk_path = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
    compiler = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--find', 'clang'], text=True).strip()
    directory = root / 'native' / 'build' / 'macos'
    libraries = []
    for architecture, triple in [('arm64', 'arm64-apple-macos'), ('amd64', 'x86_64-apple-macos')]:
        output = directory / architecture / 'libDuanjuCore.a'
        output.parent.mkdir(parents=True, exist_ok=True)
        flags = shlex.join(['-isysroot', sdk_path, '-target', triple + deployment_target])
        build_env = environment | {
            'GOOS': 'darwin', 'GOARCH': architecture, 'CC': compiler,
            'CGO_CFLAGS': flags, 'CGO_LDFLAGS': flags,
        }
        run([go, 'build', '-trimpath', '-buildmode=c-archive', '-ldflags=' + variant.linker_flags,
             '-o', str(output), './bridge'], cwd=root / 'native', env=build_env)
        libraries.append(output)
    universal = directory / 'universal'
    headers = universal / 'Headers'
    headers.mkdir(parents=True, exist_ok=True)
    archive = universal / 'libDuanjuCore.a'
    run(['xcrun', 'lipo', '-create', *map(str, libraries), '-output', str(archive)])
    shutil.copy2(libraries[0].with_suffix('.h'), headers / 'DuanjuCore.h')
    framework = root / 'macos' / 'DuanjuCore' / 'DuanjuCore.xcframework'
    if framework.exists():
        shutil.rmtree(framework)
    run(['xcodebuild', '-create-xcframework', '-library', str(archive), '-headers', str(headers),
         '-output', str(framework)])


def validate_application(application):
    executable = application / 'Contents' / 'MacOS' / 'duanju_app'
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise SystemExit('macOS 包缺少可执行文件。')
    run(['xcrun', 'lipo', str(executable), '-verify_arch', 'arm64', 'x86_64'])
    symbols = subprocess.check_output(['xcrun', 'nm', '-gU', str(executable)], text=True)
    for symbol in ['_DuanjuRequest', '_DuanjuFree']:
        if symbol not in symbols:
            raise SystemExit('macOS 包缺少 FFI 入口：' + symbol)
    run(['codesign', '--verify', '--deep', '--strict', str(application)])


def validate_package(package, prefix):
    with zipfile.ZipFile(package) as archive:
        for name in [prefix + '/Contents/MacOS/duanju_app', prefix + '/Contents/Info.plist']:
            if name not in archive.namelist() or archive.getinfo(name).file_size == 0:
                raise SystemExit('macOS 压缩包缺少必要文件：' + name)
        corrupt = archive.testzip()
        if corrupt:
            raise SystemExit('macOS 压缩包损坏：' + corrupt)


def main():
    parser = argparse.ArgumentParser(description='构建红果鉴 / 真果鉴 macOS 核心和应用')
    parser.add_argument('--core-only', action='store_true')
    add_variant_argument(parser)
    options = parser.parse_args()
    variant = BuildVariant(options.all_sources)
    build_core(variant)
    if options.core_only:
        return
    flutter = shutil.which('flutter')
    if not flutter or not shutil.which('pod'):
        raise SystemExit('请安装 Flutter 和 CocoaPods。')
    run([flutter, 'pub', 'get', '--enforce-lockfile'])
    run([flutter, 'build', 'macos', '--release', '--no-pub', *variant.flutter_arguments])
    application = root / 'build' / 'macos' / 'Build' / 'Products' / 'Release' / 'duanju_app.app'
    validate_application(application)
    output = root / 'dist' / 'macos'
    output.mkdir(parents=True, exist_ok=True)
    version = re.search(r'^version:\s*(\S+)', (root / 'pubspec.yaml').read_text(), re.MULTILINE).group(1)
    staging = output / 'staging'
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir()
    bundle = staging / f'{variant.slug}.app'
    run(['ditto', str(application), str(bundle)])
    package = output / f'{variant.slug}-{version}-macos-universal.zip'
    if package.exists():
        package.unlink()
    run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(bundle), str(package)])
    validate_package(package, bundle.name)
    shutil.rmtree(staging)
    print(package)


if __name__ == '__main__':
    main()
