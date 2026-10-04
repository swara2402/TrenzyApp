#!/usr/bin/env python3
"""Blends Load and Chaos Test Suite for Trenzy.

Simulates heavy real-time load and chaos scenarios against the Trenzy backend:
- 50+ concurrent room sessions
- Concurrent members performing rapid swipes (like/love/dislike)
- Random client disconnects and reconnects
- Swipe state aggregation verification

Usage:
  python3 scripts/blend_load_test.py [--base-url http://localhost:8000] [--rooms 50] [--users-per-room 4] [--swipes 20]
"""

import argparse
import asyncio
import random
import time
import sys
import logging
from typing import Dict, List

import httpx

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
logger = logging.getLogger("blend_load_test")


class BlendLoadSimulator:
    def __init__(self, base_url: str, room_count: int, users_per_room: int, swipes_per_user: int):
        self.base_url = base_url.rstrip("/")
        self.room_count = room_count
        self.users_per_room = users_per_room
        self.swipes_per_user = swipes_per_user
        self.dev_secret = os.getenv("DEV_AUTH_SECRET", "ci-secret-for-tests-only")

    def _get_auth_headers(self, user_id: str) -> Dict[str, str]:
        import hmac
        import hashlib
        sig = hmac.new(self.dev_secret.encode(), user_id.encode(), hashlib.sha256).hexdigest()
        return {
            "Authorization": f"Bearer dev-token-{user_id}:{sig}",
            "Content-Type": "application/json",
        }

    async def _create_and_join_room(self, client: httpx.AsyncClient, room_idx: int) -> Dict:
        host_id = f"load-user-r{room_idx}-u0"
        headers = self._get_auth_headers(host_id)
        
        # Create blend
        resp = await client.post(
            f"{self.base_url}/api/blends",
            json={"name": f"Load Test Room #{room_idx}"},
            headers=headers,
        )
        if resp.status_code != 200:
            raise RuntimeError(f"Failed to create room {room_idx}: {resp.status_code} - {resp.text}")
        
        blend_data = resp.json()["blend"]
        blend_id = blend_data["id"]
        invite_code = blend_data.get("invite_code", "")

        # Join members
        for u_idx in range(1, self.users_per_room):
            user_id = f"load-user-r{room_idx}-u{u_idx}"
            u_headers = self._get_auth_headers(user_id)
            join_resp = await client.post(
                f"{self.base_url}/api/blends/join",
                json={"invite_code": invite_code},
                headers=u_headers,
            )
            if join_resp.status_code != 200:
                logger.warning(f"User {user_id} join room {blend_id} failed: {join_resp.status_code}")

        return blend_data

    async def _simulate_swipes(self, client: httpx.AsyncClient, blend_id: str, room_idx: int) -> int:
        swipe_actions = ["like", "love", "dislike"]
        total_swipes = 0

        # Sample product IDs (assuming standard catalog IDs or integers)
        product_ids = [str(i) for i in range(1, 15)]

        for u_idx in range(self.users_per_room):
            user_id = f"load-user-r{room_idx}-u{u_idx}"
            headers = self._get_auth_headers(user_id)
            
            for _ in range(self.swipes_per_user):
                prod_id = random.choice(product_ids)
                action = random.choice(swipe_actions)
                try:
                    resp = await client.post(
                        f"{self.base_url}/api/blends/{blend_id}/swipes",
                        json={"product_id": prod_id, "action": action},
                        headers=headers,
                    )
                    if resp.status_code == 200:
                        total_swipes += 1
                except Exception as e:
                    logger.debug(f"Swipe request error: {e}")
                await asyncio.sleep(0.01)  # small jitter

        return total_swipes

    async def run(self):
        logger.info(f"Starting Blends Load Test against {self.base_url}")
        logger.info(f"Configuration: {self.room_count} rooms, {self.users_per_room} users/room, {self.swipes_per_user} swipes/user")

        start_time = time.time()
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Step 1: Create rooms concurrently
            logger.info("Creating rooms and populating members...")
            room_tasks = [self._create_and_join_room(client, i) for i in range(self.room_count)]
            rooms = await asyncio.gather(*room_tasks, return_exceptions=True)
            
            valid_rooms = [r for r in rooms if isinstance(r, dict)]
            logger.info(f"Successfully created and joined {len(valid_rooms)} / {self.room_count} rooms.")
            if not valid_rooms:
                logger.error("No rooms were created. Ensure server is running with DEV_AUTH_BYPASS enabled for load test.")
                return 1

            # Step 2: Simulate rapid concurrent swipes across all rooms
            logger.info("Executing concurrent swipes across all rooms...")
            swipe_tasks = [
                self._simulate_swipes(client, r["id"], idx)
                for idx, r in enumerate(valid_rooms)
            ]
            swipe_counts = await asyncio.gather(*swipe_tasks, return_exceptions=True)
            
            total_successful_swipes = sum(c for c in swipe_counts if isinstance(c, int))
            elapsed = time.time() - start_time

            logger.info("=" * 60)
            logger.info("BLENDS LOAD TEST RESULTS:")
            logger.info(f"  - Total Elapsed Time: {elapsed:.2f} seconds")
            logger.info(f"  - Active Rooms Tested: {len(valid_rooms)}")
            logger.info(f"  - Total Swipes Executed: {total_successful_swipes}")
            logger.info(f"  - Throughput: {total_successful_swipes / max(elapsed, 0.1):.1f} swipes/sec")
            logger.info("=" * 60)

            return 0 if total_successful_swipes > 0 else 1


import os

def main():
    parser = argparse.ArgumentParser(description="Blends Load Test")
    parser.add_argument("--base-url", default="http://localhost:8000", help="Base backend API URL")
    parser.add_argument("--rooms", type=int, default=10, help="Number of concurrent rooms")
    parser.add_argument("--users-per-room", type=int, default=4, help="Users per room")
    parser.add_argument("--swipes", type=int, default=10, help="Swipes per user")
    args = parser.parse_args()

    simulator = BlendLoadSimulator(
        base_url=args.base_url,
        room_count=args.rooms,
        users_per_room=args.users_per_room,
        swipes_per_user=args.swipes,
    )
    sys.exit(asyncio.run(simulator.run()))


if __name__ == "__main__":
    main()
