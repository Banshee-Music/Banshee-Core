import type { NextApiRequest, NextApiResponse } from "next";
import { getBansheeContract } from "../../../lib/banshee/contract";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    const { artistURI } = req.body;
    if (!artistURI) return res.status(400).json({ error: "artistURI required" });

    // This route is a template. In production, call from the connected artist wallet in the frontend,
    // or use a server custody model only if artists explicitly delegate registration.
    const contract = getBansheeContract(process.env.ARTIST_PRIVATE_KEY);
    const tx = await contract.registerArtist(artistURI);
    await tx.wait();

    return res.status(200).json({ ok: true, txHash: tx.hash });
  } catch (err: any) {
    return res.status(500).json({ error: err.message ?? "register failed" });
  }
}
