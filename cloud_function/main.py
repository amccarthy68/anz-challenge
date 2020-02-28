# import libraries
import os
from google.cloud import bigquery
import pandas as pd
import gcsfs
import datetime as dt

# specify variables from terraform script
projectId = os.environ.get("GCP_PROJECT")
bucket = os.environ["bucket"]


def extract_data(request):
    """this function is triggered by cloud scheduler and will generate daily reports
    """
    bq_client = bigquery.Client()
    # sql for repoert 1
    report_1 = """select modileNum as subscriber
                        ,url as website
                        ,sum(bytesIn) as total_downloaded
                        ,sum(bytesOut) as total_uploaded 
                    from mobile_subscriptions.subscriber_data
                where SessionEndTime >=  TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
                and SessionStartTime <=  TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
                group by modileNum,url

                """
    # sql for report 2
    report_2 = """select modileNum as subscriber
                ,url as website
                , sum(TIMESTAMP_DIFF(SessionEndTime,SessionStartTime,SECOND)) as total_session_time_seconds
                ,sum(TIMESTAMP_DIFF(SessionEndTime,SessionStartTime,MINUTE)) as total_session_time_minutes
            from mobile_subscriptions.subscriber_data
        where SessionEndTime >=  TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
        and SessionStartTime <=  TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
        group by modileNum,url
        """
    # loop to generate reports and store in bucked if there is data
    reports = {"report_1": report_1, "report_2": report_2}
    for name, query in reports.items():
        df = bq_client.query(query).result().to_dataframe()
        if df.empty:
            print("no data for today")
        else:
            df.to_csv(
                f"gs://{bucket}/{name}{dt.datetime.utcnow()}.csv",
                index=False,
                line_terminator="\n",
            )
            print(name, "completed")
