export default function Home() {
  return (
    <main style={{ padding: 40, fontFamily: "Arial, sans-serif" }}>
      <h1>Banshee Proof-of-Performance</h1>
      <p>
        Artists submit Greenfield-hosted music. BNB AI agents verify submissions,
        issue ticket NFTs, track performance, and mint BANSHEE rewards.
      </p>
      <h2>MVP API Routes</h2>
      <ul>
        <li>POST /api/artists/register</li>
        <li>POST /api/submissions/create</li>
        <li>POST /api/plays/track</li>
        <li>POST /api/agents/rewards</li>
      </ul>
    </main>
  );
}
