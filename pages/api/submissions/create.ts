import type { NextApiRequest, NextApiResponse } from "next";
import { getBansheeContract } from "../../../lib/banshee/contract";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    const {
      listingType,
      title,
      metadataURI,
      greenfieldBucket,
      greenfieldObject,
      greenfieldGroup
    } = req.body;

    if (!title || !metadataURI || !greenfieldBucket || !greenfieldObject || !greenfieldGroup) {
      return res.status(400).json({ error: "missing submission fields" });
    }

    const contract = getBansheeContract(process.env.ARTIST_PRIVATE_KEY);
    const tx = await contract.submitContent(
      listingType ?? 0,
      title,
      metadataURI,
      greenfieldBucket,
      greenfieldObject,
      greenfieldGroup
    );
    const receipt = await tx.wait();

    return res.status(200).json({ ok: true, txHash: tx.hash, blockNumber: receipt.blockNumber });
  } catch (err: any) {
    return res.status(500).json({ error: err.message ?? "submission failed" });
  }
}
