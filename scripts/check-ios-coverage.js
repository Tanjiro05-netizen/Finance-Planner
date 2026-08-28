#!/usr/bin/env node

const fs = require("node:fs");

const [, , reportPath, floorValue] = process.argv;

if (!reportPath || !floorValue) {
  console.error("Usage: check-ios-coverage.js <xccov-report.json> <floor-percent>");
  process.exit(2);
}

const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const floor = Number(floorValue);
const files = (report.targets ?? []).flatMap((target) => target.files ?? []);
const scopedFiles = files.filter((file) => {
  const path = file.path ?? "";
  return path.includes("/Sift/Core/") || path.endsWith("ViewModel.swift");
});

if (scopedFiles.length === 0) {
  console.error("No Core or ViewModel files found in xccov report.");
  process.exit(1);
}

const totals = scopedFiles.reduce(
  (sum, file) => {
    const executable = Number(file.executableLines ?? 0);
    const covered = file.coveredLines === undefined
      ? executable * Number(file.lineCoverage ?? 0)
      : Number(file.coveredLines);

    return {
      executable: sum.executable + executable,
      covered: sum.covered + covered
    };
  },
  { executable: 0, covered: 0 }
);

if (totals.executable === 0) {
  console.error("No executable lines found in scoped iOS coverage files.");
  process.exit(1);
}

const coverage = (totals.covered / totals.executable) * 100;
console.log(`Scoped iOS coverage: ${coverage.toFixed(2)}%`);

if (coverage < floor) {
  console.error(`Coverage floor not met: ${coverage.toFixed(2)}% < ${floor}%`);
  console.error("Per-file breakdown (worst first):");
  scopedFiles
    .map((file) => {
      const executable = Number(file.executableLines ?? 0);
      const covered = file.coveredLines === undefined
        ? executable * Number(file.lineCoverage ?? 0)
        : Number(file.coveredLines);
      const percent = executable === 0 ? 100 : (covered / executable) * 100;
      return { path: file.path ?? "(unknown)", executable, covered, percent };
    })
    .sort((a, b) => a.percent - b.percent)
    .forEach(({ path, executable, covered, percent }) => {
      console.error(
        `  ${percent.toFixed(1).padStart(5)}%  (${Math.round(covered)}/${executable} lines)  ${path}`
      );
    });
  process.exit(1);
}
