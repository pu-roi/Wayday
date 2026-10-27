# Wayday MapLibre patch

This directory contains the runtime source of `maplibre_gl` 0.27.1 from pub.dev, including its upstream license. The app uses it as a local path dependency. Publishing screenshots and example/test projects are omitted.

Wayday adds an `attributionButtonEnabled` map option. It defaults to true and only changes Android's native attribution button; the Today map supplies its own information control when false. The Android option is applied both at creation and on updates and retained across native view recreation. Other platforms ignore this option and keep their native behavior.

Review or upstream this patch before upgrading MapLibre. The Today map's icon-only attribution is an owner choice and differs from OpenStreetMap Foundation's published attribution safe-harbour guidance.
