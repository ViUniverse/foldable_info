"""Create a clean standalone foldable_info checkout from the source package."""
from pathlib import Path
import argparse
import shutil

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {
    '.git', '.dart_tool', 'build', 'coverage', '.DS_Store', '.idea',
    '.flutter-plugins-dependencies', '.pub-cache', '.pub', 'Pods', '.symlinks',
    '.gradle', '.cxx', '.kotlin', 'GeneratedPluginRegistrant.java', 'local.properties', 'gradlew', 'gradlew.bat', 'gradle-wrapper.jar',
    'ephemeral', 'pubspec.lock', 'pubspec_overrides.yaml', '__pycache__',
    'Generated.xcconfig', 'flutter_export_environment.sh', 'GeneratedPluginRegistrant.h',
    'GeneratedPluginRegistrant.m', '.last_build_id', 'xcuserdata',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path, help='New destination directory')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    if output == ROOT or ROOT in output.parents or output.exists():
        parser.error('Destination must be new and outside the source package.')
    shutil.copytree(ROOT, output, ignore=lambda _, names: [
        name for name in names if name in EXCLUDED or name.endswith(('.iml', '.log', '.pyc'))
    ])
    for relative in ['pubspec.yaml', 'example/pubspec.yaml']:
        pubspec = output / relative
        pubspec.write_text(pubspec.read_text().replace('resolution: workspace\n', ''))
    example = output / 'example/pubspec.yaml'
    example.write_text(example.read_text().replace('  foldable_info:\n', '  foldable_info:\n    path: ../\n'))
    print(f'Standalone package: {output}')
    print('Resolve dependencies, run checks, then review files before pushing.')


if __name__ == '__main__':
    main()
