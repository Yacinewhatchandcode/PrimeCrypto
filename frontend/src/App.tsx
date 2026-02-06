import { useState, useEffect } from 'react'
import Header from './components/Header'
import StatsOverview from './components/StatsOverview'
import StakingPanel from './components/StakingPanel'
import AgentActivity from './components/AgentActivity'
import GovernancePanel from './components/GovernancePanel'
import './App.css'

function App() {
  const [isConnected, setIsConnected] = useState(false)
  const [account, setAccount] = useState<string | null>(null)

  const connectWallet = async () => {
    if (typeof window.ethereum !== 'undefined') {
      try {
        const accounts = await window.ethereum.request({
          method: 'eth_requestAccounts'
        }) as string[]
        if (accounts && accounts.length > 0) {
          setAccount(accounts[0])
          setIsConnected(true)
        }
      } catch (error) {
        console.error('Failed to connect wallet:', error)
      }
    } else {
      alert('Please install MetaMask or another Web3 wallet')
    }
  }

  useEffect(() => {
    const checkConnection = async () => {
      if (typeof window.ethereum !== 'undefined') {
        const accounts = await window.ethereum.request({
          method: 'eth_accounts'
        }) as string[]
        if (accounts && accounts.length > 0) {
          setAccount(accounts[0])
          setIsConnected(true)
        }
      }
    }
    checkConnection()
  }, [])

  return (
    <div className="app">
      <Header
        isConnected={isConnected}
        account={account}
        onConnect={connectWallet}
      />

      <main className="main-content">
        <div className="container">
          <StatsOverview />

          <div className="dashboard-grid">
            <StakingPanel isConnected={isConnected} />
            <AgentActivity />
          </div>

          <GovernancePanel isConnected={isConnected} />
        </div>
      </main>

      <footer className="footer">
        <p>
          PrimeCrypto — AI-Native Cryptocurrency |
          <a href="https://github.com/primeai/primecrypto" target="_blank" rel="noopener noreferrer">
            GitHub
          </a>
        </p>
      </footer>
    </div>
  )
}

export default App

// Extend Window interface for ethereum
declare global {
  interface Window {
    ethereum?: {
      request: (args: { method: string; params?: unknown[] }) => Promise<unknown>
      on: (event: string, callback: (...args: unknown[]) => void) => void
    }
  }
}
