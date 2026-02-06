import './Header.css'

interface HeaderProps {
    isConnected: boolean
    account: string | null
    onConnect: () => void
}

function Header({ isConnected, account, onConnect }: HeaderProps) {
    const formatAddress = (addr: string) => {
        return `${addr.slice(0, 6)}...${addr.slice(-4)}`
    }

    return (
        <header className="header">
            <div className="header-content">
                <div className="logo">
                    <div className="logo-icon">◇</div>
                    <span className="logo-text">PrimeCrypto</span>
                    <span className="logo-badge">BETA</span>
                </div>

                <nav className="nav-links">
                    <a href="#dashboard" className="nav-link active">Dashboard</a>
                    <a href="#staking" className="nav-link">Staking</a>
                    <a href="#agents" className="nav-link">Agents</a>
                    <a href="#governance" className="nav-link">Governance</a>
                </nav>

                <div className="header-actions">
                    <div className="network-badge">
                        <span className="network-dot"></span>
                        Base
                    </div>

                    {isConnected && account ? (
                        <div className="wallet-connected">
                            <span className="wallet-balance">1,234.56 PRIME</span>
                            <span className="wallet-address">{formatAddress(account)}</span>
                        </div>
                    ) : (
                        <button className="btn btn-primary" onClick={onConnect}>
                            Connect Wallet
                        </button>
                    )}
                </div>
            </div>
        </header>
    )
}

export default Header
