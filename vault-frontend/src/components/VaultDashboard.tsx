'use client';

import { useState } from 'react';
import { useAccount, useReadContract, useWriteContract } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import YieldVaultABI from '../contracts/YieldVault.json';
import ProofOfReservesABI from '../contracts/ProofOfReserves.json';
import proofData from '../data/proof.json';
import { ConnectButton } from '@rainbow-me/rainbowkit';

const VAULT_ADDRESS = '0x265B2E9CA36715E31e1e012A4B076f8f1c3a9D7e'; 
const ORACLE_ADDRESS = '0x2560E7C7d787afB262fD81A495a25F4BA3Ea4aDC';

export default function VaultDashboard() {
  const { address, isConnected } = useAccount();
  const [amount, setAmount] = useState('');
  const [action, setAction] = useState<'deposit' | 'withdraw'>('deposit');

  const { data: totalAssets } = useReadContract({
    address: VAULT_ADDRESS,
    abi: YieldVaultABI,
    functionName: 'totalAssets',
  });

  const { data: userShares } = useReadContract({
    address: VAULT_ADDRESS,
    abi: YieldVaultABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: !!address }
  });

  const { data: isSolvent } = useReadContract({
    address: ORACLE_ADDRESS,
    abi: ProofOfReservesABI,
    functionName: 'isSolvent',
  });

  const { data: lastVerified } = useReadContract({
    address: ORACLE_ADDRESS,
    abi: ProofOfReservesABI,
    functionName: 'lastVerifiedTimestamp',
  });

  const { writeContract, isPending } = useWriteContract();

  const handleExecute = async () => {
    if (!amount || !address) return;
    const parsedAmount = parseUnits(amount, 6);

    if (action === 'deposit') {
      writeContract({
        address: VAULT_ADDRESS,
        abi: YieldVaultABI,
        functionName: 'deposit',
        args: [parsedAmount, address],
      });
    } else {
      writeContract({
        address: VAULT_ADDRESS,
        abi: YieldVaultABI,
        functionName: 'withdraw',
        args: [parsedAmount, address, address],
      });
    }
  };

  const handleSubmitProof = () => {
    writeContract({
      address: ORACLE_ADDRESS,
      abi: ProofOfReservesABI,
      functionName: 'submitProof',
      args: [
        proofData.a,
        proofData.b,
        proofData.c,
        [proofData.commitment, proofData.totalAssets, proofData.timestamp] // Assuming 3 public inputs ordered this way
      ],
    });
  };

  return (
    <div className="max-w-md mx-auto mt-12 p-6 bg-slate-900 text-white rounded-xl shadow-2xl border border-slate-800">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-2xl font-bold tracking-tight">yUSDC Vault</h1>
        <ConnectButton showBalance={false} />
      </div>

      <div className={`p-4 rounded-lg mb-6 border ${isSolvent ? 'bg-emerald-900/20 border-emerald-800' : 'bg-red-900/20 border-red-800'}`}>
        <div className="flex justify-between items-center mb-2">
          <h3 className="font-semibold">Cryptographic Solvency</h3>
          <span className={`text-xs px-2 py-1 rounded ${isSolvent ? 'bg-emerald-800 text-emerald-100' : 'bg-red-800 text-red-100'}`}>
            {isSolvent ? 'VERIFIED ✓' : 'UNVERIFIED ⚠'}
          </span>
        </div>
        <p className="text-sm text-slate-400">
          Last Verified: {lastVerified && Number(lastVerified) > 0 ? new Date(Number(lastVerified) * 1000).toLocaleString() : 'Never'}
        </p>
        <button 
          onClick={handleSubmitProof}
          className="mt-3 text-xs bg-slate-800 hover:bg-slate-700 px-3 py-1.5 rounded transition-colors"
        >
          [Admin] Submit ZK Proof
        </button>
      </div>

      <div className="bg-slate-800 p-4 rounded-lg mb-6 border border-slate-700">
        <p className="text-sm text-slate-400">Vault TVL</p>
        <p className="text-3xl font-mono">
          ${totalAssets ? formatUnits(totalAssets as bigint, 6) : '0.00'}
        </p>
        
        {isConnected && (
          <div className="mt-4 pt-4 border-t border-slate-700 flex justify-between">
            <span className="text-sm text-slate-400">Your Shares:</span>
            <span className="font-mono text-emerald-400">
              {userShares ? formatUnits(userShares as bigint, 6) : '0.00'} yUSDC
            </span>
          </div>
        )}
      </div>

      <div className="flex gap-2 mb-4">
        <button 
          onClick={() => setAction('deposit')}
          className={`flex-1 py-2 rounded-md font-semibold transition-colors ${action === 'deposit' ? 'bg-blue-600 text-white' : 'bg-slate-800 text-slate-400'}`}
        >
          Deposit
        </button>
        <button 
          onClick={() => setAction('withdraw')}
          className={`flex-1 py-2 rounded-md font-semibold transition-colors ${action === 'withdraw' ? 'bg-blue-600 text-white' : 'bg-slate-800 text-slate-400'}`}
        >
          Withdraw
        </button>
      </div>

      <div className="space-y-4">
        <input
          type="number"
          placeholder="0.00 USDC"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          className="w-full bg-slate-950 border border-slate-700 rounded-lg p-4 text-xl outline-none focus:border-blue-500 font-mono"
        />
        
        <button
          onClick={handleExecute}
          disabled={!isConnected || isPending || !amount}
          className="w-full bg-emerald-600 hover:bg-emerald-500 disabled:bg-slate-700 disabled:text-slate-500 text-white font-bold py-4 rounded-lg transition-all"
        >
          {isPending ? 'Confirming...' : `Execute ${action === 'deposit' ? 'Deposit' : 'Withdrawal'}`}
        </button>
      </div>
    </div>
  );
}