FROM python:3.9-slim
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir flask requests
EXPOSE 5000
ENV NAME World
CMD ["python", "./app.py"]

