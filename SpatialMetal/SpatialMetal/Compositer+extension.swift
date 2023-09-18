//
// Copyright © 2023 musesum.
// All Rights Reserved.


import CompositorServices

extension LayerRenderer.Clock.Instant {
    func toTimeInterval() -> TimeInterval {
        let duration = LayerRenderer.Clock.Instant.epoch.duration(to: self)
        let secondsPart = Double(duration.components.seconds)
        let attosecondsPart = Double(duration.components.attoseconds) / 1e18
        return secondsPart + attosecondsPart
    }
}
