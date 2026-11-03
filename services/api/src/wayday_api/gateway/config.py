import os
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Settings:
    project_id: str = ""
    app_ids: tuple[str, ...] = ()
    gemini_key: str = field(default="", repr=False)
    routes_key: str = field(default="", repr=False)
    geoapify_key: str = field(default="", repr=False)
    locationiq_key: str = field(default="", repr=False)
    ledger_document: str = ""
    alternative_navigation: bool = False
    geoapify_daily_credits: int = 0
    geoapify_testing_limits: bool = True

    @classmethod
    def environment(cls):
        return cls(
            project_id=os.getenv("GOOGLE_CLOUD_PROJECT", ""),
            app_ids=tuple(
                filter(None, os.getenv("WAYDAY_FIREBASE_APP_IDS", "").split(","))
            ),
            gemini_key=os.getenv("GEMINI_API_KEY", ""),
            routes_key=os.getenv("GOOGLE_ROUTES_SERVER_API_KEY", ""),
            geoapify_key=os.getenv("GEOAPIFY_API_KEY", ""),
            locationiq_key=os.getenv("LOCATIONIQ_API_KEY", ""),
            ledger_document=os.getenv("WAYDAY_PUBLIC_LEDGER_DOCUMENT", ""),
            alternative_navigation=os.getenv("WAYDAY_ALTERNATIVE_NAVIGATION", "") == "true",
            geoapify_daily_credits=int(os.getenv("WAYDAY_GEOAPIFY_DAILY_CREDITS", "0")),
            geoapify_testing_limits=os.getenv("WAYDAY_DAILY_CEILINGS", os.getenv("WAYDAY_GEOAPIFY_TEST_LIMITS", "true")) != "false",
        )


class GatewayFailure(Exception):
    def __init__(self, status: int, code: str):
        self.status, self.code = status, code
        super().__init__(code)
