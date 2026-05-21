import type { NextApiRequest, NextApiResponse } from "next";
import { ethers } from "ethers";
import { getBansheeContract } from "../../../lib/banshee/contract";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    const { listingId, listener, playCount, sessionId } = req.body;
    if (!listingId || !listener || !playCount || !sessionId) {
      return res.status(400).json({ error: "listingId, listener, playCount, sessionId required" });
    }

    const proofHash = ethers.utils.keccak256(
      ethers.utils.defaultAbiCoder.encode(
        ["uint256", "address", "uint256", "string"],
        [listingId, listener, playCount, sessionId]
      )
    );

    const contract = getBansheeContract(process.env.AI_AGENT_PRIVATE_KEY);
    const tx = await contract.recordPerformance(
      listingId,
      listener,
      playCount,
      proofHash,
      `banshee-player:${sessionId}`
    );
    await tx.wait();

    return res.status(200).json({ ok: true, txHash: tx.hash, proofHash });
  } catch (err: any) {
    return res.status(500).json({ error: err.message ?? "track failed" });
  }
}
