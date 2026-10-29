#!/usr/bin/env python3
import argparse
from collections import Counter
from pathlib import Path
import csv

ROOT = Path(__file__).resolve().parent
ANALYSIS = ROOT / 'Analysis'
SAMPLE_NAMES = ANALYSIS / 'Alignment' / 'sample_names.txt'
SAMPLE_METADATA = ANALYSIS / 'Alignment' / 'post_alignment_analysis' / 'sample_metadata.tsv'
SAMPLE_MANIFEST = ANALYSIS / 'Alignment' / 'manifests' / 'sample_manifest.tsv'

TEXT_SUFFIXES = {'.txt', '.tsv', '.csv', '.html', '.log', '.json', '.md'}

ORDER = {('1','L001'): '1', ('1','L007'): '2', ('2','L001'): '3', ('2','L007'): '4'}


def load_sample_metadata():
    rows = []
    with SAMPLE_METADATA.open() as f:
        reader = csv.DictReader(f, delimiter='\t')
        for r in reader:
            rows.append(r)
    return rows


def load_mapping_file(path):
    mapping = {}
    with Path(path).open() as f:
        header = f.readline().strip().split('\t')
        if len(header) < 2:
            raise ValueError(f'Invalid mapping file header: {header}')
        old_idx = 0
        new_idx = 1
        if 'old_sample' in header and 'new_sample' in header:
            old_idx = header.index('old_sample')
            new_idx = header.index('new_sample')
        for line in f:
            if not line.strip():
                continue
            parts = line.rstrip('\n').split('\t')
            if len(parts) < 2:
                continue
            old = parts[old_idx]
            new = parts[new_idx]
            if old in mapping and mapping[old] != new:
                raise ValueError(f'Conflicting mapping for {old}: {mapping[old]} vs {new}')
            mapping[old] = new
    return mapping


def build_mapping(rows):
    mapping = {}
    for r in rows:
        old = r['sample']
        source = 'H' if r['condition'] == 'infection' else 'B'
        time = r['timepoint'] if r['timepoint'] else '0h'
        bio = r['biological_replicate']
        tech = ORDER.get((r['run'], r['lane']))
        if tech is None:
            raise ValueError(f'Unknown run/lane combination: {r["run"]}/{r["lane"]} for {old}')
        new = f'{source}_{time}_{bio}_{tech}'
        if old in mapping:
            raise ValueError(f'duplicate sample in metadata: {old}')
        mapping[old] = new
    if len(mapping) != len(rows):
        raise ValueError('mapping length mismatch')
    if len(set(mapping.values())) != len(rows):
        raise ValueError('new sample names are not unique')
    return mapping


def replacement_pairs(mapping):
    # Sort longer old values first to avoid partial matches inside other sample names
    return sorted(mapping.items(), key=lambda item: -len(item[0]))


def find_matching_paths():
    samples = [line.strip() for line in SAMPLE_NAMES.read_text().splitlines() if line.strip()]
    paths = []
    for p in ANALYSIS.rglob('*'):
        if p.is_file():
            name = p.name
            for old in samples:
                if old in name:
                    paths.append(p)
                    break
    return sorted(paths)


def replace_in_text_file(path, mapping):
    text = path.read_text(errors='ignore')
    new_text = text
    for old, new in replacement_pairs(mapping):
        new_text = new_text.replace(old, new)
    if new_text != text:
        path.write_text(new_text)
        return True
    return False


def update_lookup_file(path, mapping):
    if not path.exists():
        return False
    text = path.read_text()
    new_text = text
    for old, new in replacement_pairs(mapping):
        new_text = new_text.replace(old, new)
    if new_text != text:
        path.write_text(new_text)
        return True
    return False


def rename_paths(mapping, dry_run=True):
    paths = []
    for p in ANALYSIS.rglob('*'):
        if p.is_file() or p.is_dir():
            name = p.name
            for old, new in replacement_pairs(mapping):
                if old in name:
                    paths.append(p)
                    break
    # sort by descending length to rename deepest items first
    paths = sorted(set(paths), key=lambda p: (-len(str(p)), str(p)))
    renamed = []
    for p in paths:
        new_name = p.name
        for old, new in replacement_pairs(mapping):
            if old in new_name:
                new_name = new_name.replace(old, new)
        if new_name != p.name:
            target = p.parent / new_name
            if target.exists():
                raise FileExistsError(f'Cannot rename {p} to {target}: target exists')
            renamed.append((p, target))
    if dry_run:
        return renamed
    for source, target in renamed:
        source.rename(target)
    return renamed


def main():
    parser = argparse.ArgumentParser(description='Rename sample prefixes across Analysis outputs.')
    parser.add_argument('--apply', action='store_true', help='Perform the rename and replacement')
    parser.add_argument('--dry-run', action='store_true', help='Show the planned changes without applying them')
    parser.add_argument('--mapping', type=Path, help='Optional TSV file with old_sample and new_sample columns')
    args = parser.parse_args()
    if args.apply and args.dry_run:
        parser.error('Cannot use --apply and --dry-run together')
    if not args.apply:
        args.dry_run = True

    if args.mapping:
        mapping = load_mapping_file(args.mapping)
    else:
        rows = load_sample_metadata()
        mapping = build_mapping(rows)
    print('Loaded', len(mapping), 'samples')
    print('Example mapping:')
    for old, new in list(mapping.items())[:10]:
        print(' ', old, '->', new)

    print('\nFinding file-system items containing old sample prefixes...')
    rename_plan = rename_paths(mapping, dry_run=True)
    print('Found', len(rename_plan), 'filesystem items to rename')
    examples = rename_plan[:10]
    for source, target in examples:
        print(' ', source.relative_to(ROOT), '->', target.relative_to(ROOT))

    print('\nScanning text files for sample IDs to replace...')
    changed = []
    for p in ANALYSIS.rglob('*'):
        if p.is_file() and p.suffix.lower() in TEXT_SUFFIXES:
            text = p.read_text(errors='ignore')
            if any(old in text for old in mapping):
                changed.append(p)
    print('Found', len(changed), 'text files with sample IDs')
    for p in changed[:10]:
        print(' ', p.relative_to(ROOT))

    if args.apply:
        print('\nApplying rename plan...')
        for source, target in rename_plan:
            print('Renaming', source.relative_to(ROOT), '->', target.relative_to(ROOT))
            source.rename(target)
        print('Updating lookup / metadata files...')
        update_lookup_file(SAMPLE_NAMES, mapping)
        update_lookup_file(SAMPLE_METADATA, mapping)
        update_lookup_file(SAMPLE_MANIFEST, mapping)

        print('\nRe-scanning text files after rename...')
        changed = []
        for p in ANALYSIS.rglob('*'):
            if p.is_file() and p.suffix.lower() in TEXT_SUFFIXES:
                text = p.read_text(errors='ignore')
                if any(old in text for old in mapping):
                    changed.append(p)
        print('Found', len(changed), 'text files with sample IDs after rename')
        for p in changed[:10]:
            print(' ', p.relative_to(ROOT))

        for p in changed:
            print('Replacing inside', p.relative_to(ROOT))
            replace_in_text_file(p, mapping)
        print('Finished.')
    else:
        print('\nDry run only; use --apply to execute changes.')

if __name__ == '__main__':
    main()
