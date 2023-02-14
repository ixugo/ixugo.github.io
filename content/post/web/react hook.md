---
title: React Hook
description: 
date: 2021-04-10 15:00:00
slug: 
image: 
draft: false
categories:
    - React
tags:
    - React
---



# React Hook

## useState

使用  `useState` 声明变量, 及修改状态

```js
function ExampleWithManyStates() {
  // 声明多个 state 变量！
  const [age, setAge] = useState(42);
  const [fruit, setFruit] = useState('banana');
  const [todos, setTodos] = useState([{ text: 'Learn Hooks' }]);
  // ...
}
```



不刷新的对象合并

```js
Object.assign(obj,{"name":"list"})
```

刷新的对象合并

```js
setObj({...obj,name:"list"})
```



## useEffect

告诉 React 在完成对 DOM 的更改后运行你的“副作用”函数。

默认情况下，React 会在每次渲染后调用副作用函数 ——包括**第一次**渲染的时候。

```
 const [count, setCount] = useState(0);

// 相当于 componentDidMount 和 componentDidUpdate:  useEffect(() => {    
	// 使用浏览器的 API 更新页面标题    
	document.title = `You clicked ${count} times`; 
});
```

#### 仅仅执行第一次

加一个 空数组即可

```js
useEffect(()=>{} ,  [])
```

1. 不写数组监听所有状态
2. 写入参数, 监听参数状态
3. 空数组, 仅首次渲染执行
4. 第一个参数函数中加返回值, 销毁时执行

```js
userEffect( ()=>{
  // 渲染后执行
  return ()=>{}
} )
```



### useRef

获取 dom 元素

```js
const inputEl = useRef(null)

<Input inputRef={inputEl} />

  inputEl.current  当前元素
  inputEl.current.value 值
```



## useContext 与 createContext

```jsx
const MyContext = createContext()

<MyContext.Provider value={count}>
  <child></child>
</MyContext.Provider>
```

![image-20201010180815347](http://img.golang.space/1602324496378-image-20201010180815347.png)





父组件刷新，子组件不会刷新

通过子组件监听 props ，重新加载数据，达到刷新的目的

![react父子组件刷新](http://img.golang.space/shot-1621254868452.png)