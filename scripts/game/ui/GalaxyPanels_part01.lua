-- Auto-split from GalaxyPanels.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function M.Init(cfg)
    onMarketCb_            = cfg.onMarketCb
    onBlackMarketCb_       = cfg.onBlackMarketCb
    onExchangeCb_          = cfg.onExchangeCb
    onShipQueueCb_         = cfg.onShipQueueCb
    onShipCancelCb_        = cfg.onShipCancelCb
    onShipPromoteCb_       = cfg.onShipPromoteCb
    getDiploRelationsCb_   = cfg.getDiploRelationsCb
    onActivateIntelCb_     = cfg.onActivateIntelCb
    onActivateAllianceCb_  = cfg.onActivateAllianceCb
    onActivateBlockadeCb_  = cfg.onActivateBlockadeCb
    onActivateMediationCb_ = cfg.onActivateMediationCb
    onSendSignalCb_        = cfg.onSendSignalCb
    notifyFn_              = cfg.notifyFn
end
