// Lambda function for Budget API (Multi-Tenant)
// Node.js 20+ compatible

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import crypto from 'crypto';

const client = new DynamoDBClient({});
const dynamodb = DynamoDBDocumentClient.from(client);
const BUDGET_TABLE = 'BudgetData';
const USERS_TABLE = 'Users';

function hashPassword(password) {
    return crypto.createHash('sha256').update(password).digest('hex');
}

function corsHeaders() {
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    };
}

export const handler = async (event) => {
    console.log('Event:', JSON.stringify(event));

    if (event.httpMethod === 'OPTIONS') {
        return { 
            statusCode: 200, 
            headers: corsHeaders(), 
            body: '' 
        };
    }

    try {
        const path = event.path;
        const method = event.httpMethod;

        // POST /register - Register new user
        if (method === 'POST' && path === '/register') {
            const body = JSON.parse(event.body);
            
            const existingUser = await dynamodb.send(new GetCommand({
                TableName: USERS_TABLE,
                Key: { username: body.username }
            }));

            if (existingUser.Item) {
                return {
                    statusCode: 400,
                    headers: corsHeaders(),
                    body: JSON.stringify({ error: 'Username already exists' })
                };
            }

            await dynamodb.send(new PutCommand({
                TableName: USERS_TABLE,
                Item: {
                    username: body.username,
                    password: hashPassword(body.password),
                    createdAt: new Date().toISOString()
                }
            }));

            return {
                statusCode: 200,
                headers: corsHeaders(),
                body: JSON.stringify({ success: true, username: body.username })
            };
        }

        // POST /login - Login user
        if (method === 'POST' && path === '/login') {
            const body = JSON.parse(event.body);
            
            const user = await dynamodb.send(new GetCommand({
                TableName: USERS_TABLE,
                Key: { username: body.username }
            }));

            if (!user.Item || user.Item.password !== hashPassword(body.password)) {
                return {
                    statusCode: 401,
                    headers: corsHeaders(),
                    body: JSON.stringify({ error: 'Invalid credentials' })
                };
            }

            return {
                statusCode: 200,
                headers: corsHeaders(),
                body: JSON.stringify({ success: true, username: body.username })
            };
        }

        // GET /budget/{userId}/{yearMonth}
        if (method === 'GET' && path.includes('/budget/')) {
            const parts = path.split('/');
            const userId = parts[2];
            const yearMonth = parts[3];

            const result = await dynamodb.send(new GetCommand({
                TableName: BUDGET_TABLE,
                Key: { userId, yearMonth }
            }));

            return {
                statusCode: 200,
                headers: corsHeaders(),
                body: JSON.stringify(result.Item || { income: [], expenses: [] })
            };
        }

        // POST /budget - Save data
        if (method === 'POST' && path === '/budget') {
            const body = JSON.parse(event.body);
            
            await dynamodb.send(new PutCommand({
                TableName: BUDGET_TABLE,
                Item: {
                    userId: body.userId,
                    yearMonth: body.yearMonth,
                    income: body.income,
                    expenses: body.expenses,
                    updatedAt: new Date().toISOString()
                }
            }));

            return {
                statusCode: 200,
                headers: corsHeaders(),
                body: JSON.stringify({ success: true })
            };
        }

        return {
            statusCode: 404,
            headers: corsHeaders(),
            body: JSON.stringify({ error: 'Not found' })
        };

    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers: corsHeaders(),
            body: JSON.stringify({ error: error.message })
        };
    }
};
