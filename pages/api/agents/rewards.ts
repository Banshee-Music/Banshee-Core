import type { NextApiRequest, NextApiResponse } from "next";
import { ethers } from "ethers";
import { getBansheeContract } from "../../../lib/banshee/contract";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const secret = req.headers["x-ai-agent-secret"];
  if (!process.env.AI_AGENT_API_SECRET || secret !== process.env.AI_AGENT_API_SECRET) {
    return res.status(401).json({ error: "unauthorized" });
  }

  try {
    const { listingId, amount, epoch, subqueryProofId } = req.body;
    if (!listingId || !amount || !epoch || !subqueryProofId) {
      return res.status(400).json({ error: "listingId, amount, epoch, subqueryProofId required" });
    }

    const proofHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(String(subqueryProofId)));
    const amountWei = ethers.utils.parseEther(String(amount));

    const contract = getBansheeContract(process.env.AI_AGENT_PRIVATE_KEY);
    const tx = await contract.mintArtistPerformanceReward(listingId, amountWei, epoch, proofHash);
    await tx.wait();

    return res.status(200).json({ ok: true, txHash: tx.hash, proofHash });
  } catch (err: any) {
    return res.status(500).json({ error: err.message ?? "reward failed" });
  }
}
