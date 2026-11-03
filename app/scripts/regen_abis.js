#!/usr/bin/env node
/**
 * Regenerate Flutter ABI dart files from Hardhat artifacts.
 *
 * Usage (from repo root):
 *   cd contracts && npx hardhat compile
 *   node app/scripts/regen_abis.js
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '../..');

function writeAbi(artifactRel, dartRel, constName) {
  const artifactPath = path.join(root, artifactRel);
  const dartPath = path.join(root, dartRel);
  const art = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
  const abi = JSON.stringify(art.abi, null, 2);
  const body =
    '// GENERATED from Hardhat artifact — do not edit by hand.\n' +
    `// Source: ${artifactRel}\n` +
    '// Regenerate after ABI changes in contracts/interfaces/IContracts.sol.\n' +
    '//   cd contracts && npx hardhat compile && node ../app/scripts/regen_abis.js\n\n' +
    `const String ${constName} = r'''${abi}''';\n`;
  fs.writeFileSync(dartPath, body);
  console.log(`wrote ${dartRel} (${art.abi.length} ABI entries)`);
}

writeAbi(
  'contracts/artifacts/contracts/ContractFactory.sol/ContractFactory.json',
  'app/lib/data/abis/contract_factory_abi.dart',
  'kContractFactoryAbiJson',
);
writeAbi(
  'contracts/artifacts/contracts/templates/Escrow.sol/Escrow.json',
  'app/lib/data/abis/escrow_abi.dart',
  'kEscrowAbiJson',
);
