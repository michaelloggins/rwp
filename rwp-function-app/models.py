from dataclasses import dataclass
from datetime import date, datetime

import azure.functions as func


@dataclass
class RWPRequest:
    """Validated request parameters for the RWP API."""

    cal_date: date
    cal_end: date
    report_type: str  # 'RWP' or 'RWPCFO'
    output_format: str  # 'json' or 'csv'

    @classmethod
    def from_request(cls, req: func.HttpRequest) -> "RWPRequest":
        cal_date_str = req.params.get("CalDate")
        cal_end_str = req.params.get("CalEnd")
        report_type = req.params.get("ReportType", "RWP").upper()
        output_format = req.params.get("Format", "json").lower()

        if not cal_date_str:
            raise ValueError("CalDate parameter is required (YYYY-MM-DD)")
        if not cal_end_str:
            raise ValueError("CalEnd parameter is required (YYYY-MM-DD)")

        try:
            cal_date = datetime.strptime(cal_date_str, "%Y-%m-%d").date()
        except ValueError:
            raise ValueError(
                f"CalDate '{cal_date_str}' is not valid. Use YYYY-MM-DD format."
            )

        try:
            cal_end = datetime.strptime(cal_end_str, "%Y-%m-%d").date()
        except ValueError:
            raise ValueError(
                f"CalEnd '{cal_end_str}' is not valid. Use YYYY-MM-DD format."
            )

        if cal_end < cal_date:
            raise ValueError("CalEnd must be >= CalDate")

        if report_type not in ("RWP", "RWPCFO"):
            raise ValueError("ReportType must be 'RWP' or 'RWPCFO'")

        if output_format not in ("json", "csv"):
            raise ValueError("Format must be 'json' or 'csv'")

        return cls(
            cal_date=cal_date,
            cal_end=cal_end,
            report_type=report_type,
            output_format=output_format,
        )
